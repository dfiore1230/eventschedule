# Quick Reference Guide

## Talent Management

### Adding Talent
1. Navigate to **Talent** tab
2. Tap **+** button in top-right
3. Fill in the form (only Name is required)
4. Tap **Add**

### Editing Talent
- **Option 1**: Swipe left on talent → Tap blue **Edit** button
- **Option 2**: Long-press talent → Select **Edit**

### Deleting Talent
- **Option 1**: Swipe left on talent → Tap red **Delete** button
- **Option 2**: Long-press talent → Select **Delete**
- Confirm deletion in alert dialog

---

## Venue Management

### Adding Venues
1. Navigate to **Venues** tab
2. Tap **+** button in top-right
3. Fill in the form (only Name is required)
4. Tap **Add**

### Editing Venues
- **Option 1**: Swipe left on venue → Tap blue **Edit** button
- **Option 2**: Long-press venue → Select **Edit**

### Deleting Venues
- **Option 1**: Swipe left on venue → Tap red **Delete** button
- **Option 2**: Long-press venue → Select **Delete**
- Confirm deletion in alert dialog

---

## Ticket Management

### Viewing Ticket Details
- Tap on any ticket to see full details and available actions

### Sorting Tickets
1. Tap the **Sort** button (↕️) in top-right
2. Select sort option:
   - **Event** - Groups tickets by event name
   - **Status** - Groups by payment status
   - **Name** - Alphabetical by customer name
   - **Date** - Most recent first

### Marking as Paid/Unpaid
- **Swipe Left**: Access Mark as Paid (pending tickets) or Mark as Unpaid (paid tickets)
- **Long-press**: Select **Mark as Paid** or **Mark as Unpaid**
- **Detail View**: Tap ticket → Tap action button

### Canceling Tickets
- **Swipe Right**: Tap **Cancel** (active tickets only)
- **Long-press**: Select **Cancel**
- **Detail View**: Tap ticket → Tap **Cancel Ticket**

### Deleting Tickets
- **Swipe Left** all the way → Tap red **Delete** button
- **Long-press**: Select **Delete**
- Confirm deletion in alert dialog

---

## Server Management

### Adding a Server
1. Navigate to **Settings** tab
2. Scroll to **Servers** section
3. Tap **Add Server**
4. Fill in server details:
   - Display Name (e.g., "Production Server")
   - Base URL (e.g., "https://api.example.com")
   - Environment (Production, Staging, or Dev)
   - Auth Method (Sanctum, OAuth2, or JWT)
5. Tap **Add**

### Switching Servers
- **Option 1**: Settings → Servers → Tap the server you want to use
- **Option 2**: Tap the server badge in any tab's navigation bar → Select server
- Active server is marked with a checkmark (✓)

### Viewing Server Badge
- Located in top-right of navigation bar
- Shows first 3 letters of active server name
- Badge number indicates total servers (if more than 1)
- Tap to see dropdown of all servers

### Deleting Servers
1. In Settings → Servers section
2. Swipe left on server → Tap **Delete**
3. Or long-press server → Select **Delete Server**
4. Confirm deletion in alert dialog
5. **Note**: This removes authentication data for that server

### Active Server Details
- View in Settings under "Active Server Details"
- Shows:
  - Server name
  - Full URL
  - Environment type
  - Authentication method
- Manage API key in sections below

---

## Tips & Tricks

### General
- Pull down to refresh any list
- Swipe actions provide quick access to common operations
- Long-press for additional options
- All delete operations require confirmation

### Multi-Server
- Each server maintains separate authentication
- Switching servers reloads all data
- You can have different API keys for each server
- Server badge shows at-a-glance which server you're using

### Tickets
- Event sorting automatically groups tickets by event
- Use search bar to find specific tickets
- Status colors: Green = Paid, Orange = Pending, Red = Cancelled

### Forms
- Only required fields are marked (usually just name)
- Cancel button discards all changes
- Form validation happens before submission
- Error messages appear at bottom of form
