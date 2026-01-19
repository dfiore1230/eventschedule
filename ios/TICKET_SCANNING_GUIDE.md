# Ticket Scanning Guide - iOS Implementation

## Overview
The iOS app now supports the updated ticket scanning API with simplified QR codes and enhanced validation.

## QR Code Formats

The app supports **two formats** for backward compatibility:

### 1. New Format (Current)
Plain ticket code string:
```
wk8wfyzjrbrdv5rxvjxjzpx9ggum6uxl
```

### 2. Legacy Format (Backward Compatible)
URL with embedded code:
```
https://testevents.fior.es/ticket/view/Mzg5Mjg2/wk8wfyzjrbrdv5rxvjxjzpx9ggum6uxl
```

The app automatically detects and parses both formats.

## API Endpoint

```
POST https://your-domain.com/api/tickets/scan
```

### Request Body
```json
{
  "ticket_code": "wk8wfyzjrbrdv5rxvjxjzpx9ggum6uxl",
  "sale_ticket_id": 789,      // Optional
  "seat_number": "A12"         // Optional
}
```

**Note**: `event_id` is NO LONGER required in the request body. The backend determines the event from the ticket code.

## Validation Requirements

Tickets must meet ALL requirements to scan successfully:

| Requirement | Error Status | User Message |
|-------------|--------------|--------------|
| Ticket must exist | 404 | "Ticket not found" |
| Ticket must be for TODAY | 400 → `wrongDate` | "This ticket is not valid for today" |
| Ticket must be PAID | 400 → `unpaid` | "This ticket is not paid" |
| Ticket cannot be CANCELLED | 400 → `cancelled` | "This ticket is cancelled" |
| Ticket cannot be REFUNDED | 400 → `refunded` | "This ticket is refunded" |
| User must manage event | 403 | "You are not authorized to scan this ticket" |

## ScanResult Status Enum

New status values added:

```swift
enum Status: String, Codable {
    case admitted           // ✅ Success - ticket scanned
    case alreadyUsed       // ⚠️ Already scanned today
    case refunded          // ❌ Ticket was refunded
    case voided            // ❌ Ticket was voided
    case wrongEvent        // ❌ Ticket for different event
    case wrongDate         // 🆕 Ticket not for today
    case unpaid            // 🆕 Payment not completed
    case cancelled         // 🆕 Ticket was cancelled
    case expired           // ❌ Ticket expired
    case invalid           // ❌ Invalid ticket or other error
    case unknown           // ❌ Unknown error
}
```

## Error Handling Flow

```
QR Scanned
    ↓
Parse Code (plain or URL)
    ↓
Call POST /api/tickets/scan
    ↓
┌─ 201 Success → Show ✅ "Admitted - [Name]"
├─ 400 + "not valid for today" → Show 📅 "This ticket is not valid for today"
├─ 400 + "not paid" → Show 💳 "This ticket is not paid"
├─ 400 + "cancelled" → Show 🚫 "This ticket is cancelled"
├─ 400 + "refunded" → Show 💸 "This ticket is refunded"
├─ 403 → Show 🔒 "You are not authorized to scan this ticket"
├─ 404 → Show ❓ "Ticket not found"
└─ Other → Show ⚠️ [Error message from server]
```

## Implementation Files

### Models
- **CheckIn.swift**: `ScanResult` with new status cases

### Repositories
- **CheckInRepository.swift**: 
  - Parses both QR formats
  - Sends simplified request (no event_id)
  - Maps 400 errors to specific statuses

### UI
- **EventDetailView.swift**:
  - Shows scan button
  - Displays toast with status
  - Debug overlay shows parsed code and resolved sale_ticket_id

### Components
- **QRScannerView.swift**: Camera-based QR scanner with cleanup

## Debug Overlay

When scanning, a temporary debug overlay shows:
```
QR Debug Info
Code: wk8wfyzjrbrdv5rxvjxjzpx9ggum6uxl
Event ID: 389286               // From legacy URL format only
Sale Ticket ID: 12345          // If resolved from search
```

This helps diagnose scanning issues.

## Testing

### Valid Ticket Test
1. Create a paid ticket for TODAY's date in the backend
2. Note the sale's `secret` field (this is the ticket code)
3. Generate QR with the code or URL format
4. Scan in the app
5. Should see: ✅ "Admitted - [Buyer Name]"

### Date Validation Test
1. Create a paid ticket for TOMORROW
2. Scan today
3. Should see: 📅 "This ticket is not valid for today"

### Payment Validation Test
1. Create an UNPAID ticket for today
2. Scan it
3. Should see: 💳 "This ticket is not paid"

### Not Found Test
1. Scan a random string: `invalid-code-12345`
2. Should see: ❓ "Ticket not found"

## Common Issues

### "Ticket not found" (404)
- **Cause**: Code doesn't exist in database
- **Fix**: Verify the ticket code is correct; ensure you're using the right environment (test vs production)

### "This ticket is not valid for today" (400)
- **Cause**: Ticket's event date ≠ device's current date
- **Fix**: Check device date/time settings; only scan tickets on their event date

### "This ticket is not paid" (400)
- **Cause**: Payment not completed
- **Fix**: Collect payment before scanning; mark as paid in admin dashboard

### "You are not authorized to scan this ticket" (403)
- **Cause**: API key doesn't belong to event organizer
- **Fix**: Verify API key permissions in backend

## Migration Notes

### Breaking Changes from Previous Version
1. **QR Format**: Now supports plain codes (not just URLs)
2. **Request Body**: Removed `event_id` requirement
3. **New Validation**: Date and payment status checks
4. **New Errors**: 400 status for validation failures (was 404 before)

### Backward Compatibility
- ✅ Legacy URL format still works
- ✅ Event ID extraction for debugging (not sent to API)
- ✅ Same authentication mechanism

## Support

For issues:
1. Check debug overlay for parsed values
2. Verify API key authentication
3. Confirm device date/time is correct
4. Test with known-valid ticket code
5. Contact backend team with error details and ticket code

---

**Last Updated**: December 17, 2025  
**API Version**: v2.0  
**iOS App Version**: 1.0.0-beta
