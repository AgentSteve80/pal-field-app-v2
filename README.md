# PreWire Pro

A professional iOS app for low voltage technicians to track jobs, generate invoices, manage expenses, and streamline workflow.

## Features

### 📋 Job Management
- **Smart Job Numbering**: Weekly auto-numbering (JB1, JB2, etc.) that resets every Monday
- **Comprehensive Job Tracking**:
  - Wire runs, enclosures, flat panels (stud/wall/remote)
  - Flex tube, media boxes, dry runs, service runs
  - Mileage tracking with automatic calculation from address
  - Pay tier support (Tier 1, 2, 3) with automatic pricing
- **Job Details**: Lot number, address, subdivision, prospect number, job date
- **Live Totals**: Real-time calculation of job totals as you enter data
- **Quick Entry**: Auto-populated job numbers, easy data entry with steppers

### 📧 Email Integration (Gmail)
- **Automatic Job Creation**: Import jobs directly from scheduling emails
- **Smart Email Parsing**:
  - Extracts lot number, subdivision, prospect from subject line
  - Parses job details from email body
  - Supports format: "(P) 127 Courtyards Russell 52260357"
- **OCR Image Scanning**: Automatically scans email attachments for:
  - Street addresses
  - Account/Prospect numbers
- **Offline-First Architecture**:
  - Instant email loading from local cache
  - Auto-sync in background
  - Works perfectly with poor cell service at worksites
- **Smart Filtering**:
  - Default "Scheduling Only" filter for job emails
  - "Last 7 Days" filter for recent messages
- **Image Gallery**: View work order images and PDFs directly in app

### 💰 Invoice Generation
- **Weekly Invoices**: Generate professional PDF invoices for each week
- **Auto-Calculation**: Totals all jobs from Monday-Sunday
- **PDF Export**: Share or save invoices as PDF
- **Invoice History**: View all past invoices with search and filtering
- **Job Breakdown**: Detailed line items for each job on invoice

### 💳 Expense Tracking
- **Receipt Scanning with AI**:
  - **Background Removal**: Automatically removes background from receipt photos
  - **OCR Text Recognition**: Scans receipts to extract:
    - Total amount
    - Merchant/store name
    - Date of purchase
  - **Auto-Fill**: Automatically populates fields from scanned receipts
- **Categories**: Gas, Supplies, Meals, Other
- **Photo Receipts**: Attach photos for tax records
- **Tax Deduction Ready**: Track all business expenses
- **Date Range Filtering**: View expenses by category and date
- **Receipt Viewer**: Full-screen receipt photo viewing

### ☁️ Automatic iCloud Backup
- **Automatic Daily Backups**: Set it and forget it
- **Flexible Scheduling**:
  - Daily
  - Every 3 days
  - Weekly
- **Smart Storage**: Keeps last 10 backups, auto-deletes old ones
- **One-Tap Restore**: Easy restoration from any backup
- **No Extra Login**: Uses your existing iCloud account
- **What's Backed Up**:
  - All jobs
  - All invoices (including PDFs)
  - All expenses (including receipt photos)

### 💾 Manual Backup & Restore
- **Export Backup**: Create .plvbackup file with all data
- **Import Options**:
  - Merge: Keep existing data, add imported items
  - Replace: Fresh start with backup data
- **Portable**: Share backups via Files app, email, etc.

### 🌤️ Weather Integration
- **Current Conditions**: Temperature, feels like, conditions
- **5-Day Forecast**: Plan your week ahead
- **Weather Alerts**: Severe weather warnings for Indiana
- **Work Planning**: Know if outdoor work is feasible
- **Location**: Indianapolis area weather

### 📊 Dashboard & Analytics
- **Week vs. Year Stats**: Side-by-side comparison
- **Quick Metrics**:
  - Job count
  - Total pay
  - Miles driven
- **Tax Calculations**:
  - Mileage deduction (2025 IRS rate: $0.67/mile)
  - Net income after deductions
  - Quarterly tax estimates
- **Recent Jobs**: Quick access to latest jobs
- **Quick Actions**: Messages, Invoices, Expenses shortcuts

### ⚙️ Settings & Customization
- **Personal Info**: Worker name, home address
- **Pay Tier Selection**: Choose your current tier (1, 2, or 3)
- **Dark Mode**: Toggle dark/light theme
- **Backup Management**: iCloud and manual backup controls

### 🎨 User Experience
- **Keyboard Management**: "Done" button to dismiss keyboard on all forms
- **Offline Support**: Works without internet connection
- **Fast Performance**: Instant loading with cached data
- **Clean Interface**: Modern, intuitive SwiftUI design
- **Smart Defaults**: Pre-filled fields, automatic calculations
- **Error Handling**: Clear error messages and recovery options

## Technical Details

### Built With
- **SwiftUI**: Modern declarative UI framework
- **SwiftData**: Persistent local storage
- **Vision Framework**: OCR and image processing
- **Core Image**: Receipt background removal
- **MapKit**: Address geocoding and mileage calculation
- **iCloud Drive**: Automatic cloud backups
- **Gmail API**: Email integration
- **OpenWeatherMap API**: Weather data
- **National Weather Service API**: Weather alerts

### Requirements
- iOS 17.0 or later
- iCloud account (for automatic backups)
- Gmail account (optional, for email integration)
- OpenWeatherMap API key (free, for weather features)

### Data Privacy
- All data stored locally on device
- Optional iCloud backup to YOUR iCloud account
- No third-party data sharing
- Gmail access only when explicitly authorized

## Setup

### Weather API Key
1. Sign up for free at [OpenWeatherMap](https://openweathermap.org/api)
2. Get your API key
3. Add it to `WeatherService.swift` (line 19)

### Gmail Integration
1. Open Messages tab
2. Tap "Sign In with Google"
3. Authorize Gmail access
4. Emails sync automatically

### iCloud Backup
1. Ensure signed in to iCloud on device
2. Go to Settings → iCloud Backup
3. Toggle "Automatic iCloud Backup" ON
4. Choose backup frequency
5. Done! Automatic backups will run in background

## Usage Tips

### Quick Job Entry
1. Messages tab → Tap scheduling email
2. Review auto-filled job details
3. Adjust quantities as needed
4. Tap "Create Job"

### Weekly Workflow
1. **Monday**: Job numbers reset to JB1
2. **During Week**: Add jobs as they come in
3. **Friday/Sunday**: Generate weekly invoice
4. **Weekly**: Auto backup to iCloud (if enabled)

### Tax Time
1. Expenses tab → View all deductions
2. Filter by date range (tax year)
3. Export backup for records
4. Use mileage deduction from dashboard

## Version History

### Current Version
- Weekly job numbering (resets every Monday)
- Email-to-job import with OCR
- Receipt scanning with background removal
- Automatic iCloud backup
- Offline-first email caching
- Weather integration
- Comprehensive expense tracking

## Support

For issues or questions:
- Check Settings → Backup & Restore to export your data
- Automatic daily backups protect your data
- All data stored securely on your device and iCloud

## License

Copyright © 2025. All rights reserved.

---

**Made for low voltage professionals who need a reliable, fast, and smart job tracking solution.** ⚡
