# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PreWire Pro is a SwiftUI iOS application for tracking prewire jobs (low-voltage electrical work) and generating invoices. It manages job data, calculates pricing and taxes, generates PDF invoices, and exports CSV reports for 1099 tax purposes.

## Build & Run

Build and run in Xcode:
```bash
open "PreWire Pro.xcodeproj"
```

Or build from command line:
```bash
xcodebuild -project "PreWire Pro.xcodeproj" -scheme "PreWire Pro" -sdk iphoneos build
```

For simulator:
```bash
xcodebuild -project "PreWire Pro.xcodeproj" -scheme "PreWire Pro" -sdk iphonesimulator build
```

## Architecture

### Data Layer
- **SwiftData** for persistent storage (single model container)
- **Job model** (`Job.swift`): Core entity with `@Model` macro, includes UUID, job details, pricing items, and calculated properties
- **Settings** (`Settings.swift`): `ObservableObject` using `UserDefaults` for app-wide settings (worker name, home address, dark mode)

### View Hierarchy
```
PreWireProApp (root)
└── ContentView (main job list + dashboard)
    ├── AddJobView (sheet)
    ├── EditJobView (NavigationLink)
    ├── WeeklyInvoiceView (sheet)
    └── SettingsView (sheet)
```

### Key Architectural Patterns
- **Environment injection**: Settings passed via `@EnvironmentObject`, SwiftData context via `@Environment(\.modelContext)`
- **SwiftData queries**: `@Query` macro for reactive data fetching (e.g., `@Query(sort: \Job.jobDate, order: .reverse)`)
- **Live calculations**: Both AddJobView and EditJobView use a temporary `sampleJob` instance that mirrors user input to show real-time pricing updates
- **Shared calculation logic**: All pricing calculations live in `Job` model as computed properties (`itemsSubtotal`, `milesCharge`, `total`)

## Business Logic

### Pricing Structure (Job.swift)
Fixed prices per item:
- Wire runs: $9 each
- Enclosure: $12 (flat rate)
- Flat panel same stud: $20 each
- Flat panel same wall: $25 each
- Flat panel remote: $30 each
- Flex tube: $35 each
- Media box: $12 (flat rate)
- Mileage: $0.75/mile (charged to customer)

Total = itemsSubtotal + milesCharge

### Tax Calculations (ContentView.swift)
- **Mileage deduction**: Total miles × $0.67 (2025 IRS rate)
- **Net income**: Total income - mileage deduction
- **Quarterly tax estimate**: max(0, netIncome × 0.153) / 4 (self-employment tax)

### Mileage Calculation
Both AddJobView and EditJobView include async MapKit integration:
- Uses `MKLocalSearch` to geocode home address and job address
- Calculates driving distance via `MKDirections`
- Falls back to manual geocode query refinement if geocoding fails
- Default query format: `"{address} subdivision, north Indianapolis, IN"`

### PDF Invoice Generation (WeeklyInvoiceView.swift)
- **Multi-page PDFs**: Summary page (30-row table) + detail pages (one per job)
- **US Letter size**: 612×792 points
- **Rendering**: Uses `UIGraphicsPDFRenderer` with CoreGraphics drawing
- **Branding**: Orange headers with company info, phone number (hardcoded: 7654300731)
- **File naming**: `Invoice_{MM-dd}_to_{MM-dd}-{year}.pdf`
- Summary page shows all jobs (filled and blank rows up to 30)
- Detail pages break down pricing items per job with line-by-line costs

### CSV Export (ContentView.swift)
- **Format**: Job #, Date, Lot, Address, Prospect, Wires, Total $, Miles
- **File name**: `PreWire_1099_Jobs.csv`
- Uses `FileDocument` protocol with `.commaSeparatedText` UTType
- Exported via `fileExporter` modifier

## File Organization

```
PreWire Pro/
├── PreWireProApp.swift        # App entry point, SwiftData setup
├── Job.swift                  # Core data model with pricing logic
├── Settings.swift             # App settings (ObservableObject)
├── ContentView.swift          # Main list view + dashboard + CSV export
├── AddJobView.swift           # Create new job (with live pricing preview)
├── EditJobView.swift          # Edit existing job (with live pricing preview)
├── WeeklyInvoiceView.swift    # Weekly summary + PDF generation
└── SettingsView.swift         # Settings form
```

## Important Implementation Details

### Job Validation
Jobs require `jobNumber`, `lotNumber`, and `address` to be non-empty before saving (enforced via `.disabled()` on Save buttons).

### Date Handling
- Week calculations use `Calendar.dateComponents([.yearForWeekOfYear, .weekOfYear])` to snap to Monday
- All date formatting for PDFs uses `DateFormatter` or `formatted()` with explicit patterns

### SwiftData Context
- Model container configured in `PreWireProApp` with `.modelContainer(for: Job.self)`
- All views access via `@Environment(\.modelContext)`
- Jobs deleted via `modelContext.delete()` with swipe actions
- Changes saved with `try? modelContext.save()`

### State Management Pattern
AddJobView and EditJobView both:
1. Maintain separate `@State` properties for each form field
2. Use a `JobInputs` struct to track changes to pricing-related fields
3. Update a `sampleJob` instance via `.onChange(of: jobInputs)` to calculate live totals
4. On save, create/update the real Job model and save to context

This pattern ensures pricing calculations are reactive without directly mutating the SwiftData model during editing.
