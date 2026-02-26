//
//  AUTOMATION_GUIDE.md
//  Pal Field
//
//  Created by Andrew Stewart on 12/13/25.
//

# Email Job Import Automation Guide

## Overview

Pal Field now supports importing jobs from email! There are three ways to import jobs from emails:

1. **Manual Import** - Copy/paste email into the app
2. **Share Extension** - Forward emails directly to the app (requires Share Extension setup)
3. **Shortcuts Automation** - Automatically parse emails with iOS Shortcuts

## Method 1: Manual Import (Available Now)

### How to Use:
1. Open Pal Field
2. Tap the **+** button → **Import from Email**
3. Copy your job notification email
4. Paste it into the text field
5. Tap **Parse**
6. Review the parsed job details
7. Tap **Import Job** or **Edit Before Import**

### Email Format Tips:
Your email should contain:
- **Job Number**: "JB12345" or "Job #: 12345"
- **Lot Number**: "Lot: 123" or "Lot #123"
- **Date**: "12/13/2025" or "2025-12-13"
- **Wire Runs**: "Wire Runs: 10" or "Wires: 10"
- **Other quantities**: Label followed by number

Example email:
```
New Job Assignment

Job #: JB12345
Lot: 123
Date: 12/13/2025
Address: 123 Main St
Builder: ABC Homes

Wire Runs: 10
Enclosure: 1
Flat Panel Same Stud: 2
Flat Panel Same Wall: 1
Media Box: 1
Miles: 15
```

## Method 2: iOS Shortcuts Automation (Recommended)

### Setup Instructions:

#### Step 1: Create a Shortcut
1. Open the **Shortcuts** app
2. Tap **+** to create a new shortcut
3. Name it "Import PalField Job"

#### Step 2: Build the Shortcut
Add these actions:

1. **Get Latest Emails** (from Mail)
   - Sender: (your job notification sender email)
   - Subject Contains: (optional - filter by subject)
   - Get: 1 email

2. **Get Text from Input**
   - This extracts the email body

3. **Run Shortcut** → "Import Job from Email" (provided by Pal Field)
   - Email Text: (use the text from previous step)

4. **Show Notification** (optional)
   - Show the result message

#### Step 3: Create an Automation
1. Open **Shortcuts** app → **Automation** tab
2. Tap **+** → **Create Personal Automation**
3. Choose trigger:
   - **Time of Day**: Run at specific time (e.g., 6 AM daily)
   - **Email**: When you receive email from sender (iOS 16+)

4. Add action: **Run Shortcut** → Select "Import PalField Job"
5. Turn OFF "Ask Before Running" for automatic operation
6. Tap **Done**

### Example Automations:

#### Daily Morning Check
- Trigger: Time of Day at 6:00 AM
- Runs: Daily
- Action: Run "Import PalField Job" shortcut

#### On Email Receipt (iOS 16+)
- Trigger: Email received from "jobs@example.com"
- Action: Run "Import PalField Job" shortcut
- Asks: No (automatic)

## Method 3: Email Rules + Shortcuts (Advanced)

### Gmail Forwarding Setup:
1. In Gmail, go to Settings → Filters
2. Create a filter for job notification emails
3. Forward to a dedicated email address
4. Use Mail app rules to trigger Shortcut

### Apple Mail Rules:
1. Open Mail → Preferences → Rules
2. Create a rule for job emails
3. Action: Run AppleScript or Shortcut (macOS only)

## Troubleshooting

### "Could not parse job from email"
- Ensure email contains at least a lot number
- Check that numbers are near their labels
- Use "Edit Before Import" to manually correct values

### Job imports with wrong date
- Make sure date is in MM/DD/YYYY format
- Check that date appears near "Date:" label

### Missing quantities
- Ensure each item has a clear label
- Numbers should be on same line or next line after label
- Use keywords: "Wire Run", "Enclosure", "Flat Panel", etc.

### Shortcut doesn't run automatically
- Check automation is enabled
- Ensure "Ask Before Running" is OFF
- iOS must be updated to latest version
- Some triggers require device to be unlocked

## Best Practices

1. **Test manually first**: Use manual import to verify your email format works
2. **Start simple**: Begin with manual import, then add automation
3. **Review imports**: Occasionally check imported jobs for accuracy
4. **Keep email format consistent**: Work with your dispatcher to standardize job emails
5. **Backup regularly**: Use "Export All to CSV" feature weekly

## Email Template Request

Ask your dispatcher to send job notifications in this format:

```
Subject: New Job Assignment - Lot [LOT_NUMBER]

Job Number: JB[NUMBER]
Lot: [LOT_NUMBER]
Date: [MM/DD/YYYY]
Address: [STREET ADDRESS]
Builder: [BUILDER_NAME]

-- Pal Field Items --
Wire Runs: [NUMBER]
Enclosure: [NUMBER]
Flat Panel Same Stud: [NUMBER]
Flat Panel Same Wall: [NUMBER]
Flat Panel Remote: [NUMBER]
Flex Tube: [NUMBER]
Media Box: [NUMBER]

-- Additional --
Dry Run: [NUMBER]
Service Run: [NUMBER]
Miles from shop: [NUMBER]

Total: $[AMOUNT]
```

This standardized format will ensure 100% accuracy when parsing.

## Support

For issues or questions:
1. Check console logs (Debug → View Console in Xcode)
2. Test with the manual import feature
3. Verify email format matches examples above
4. Check iOS Shortcuts permissions
