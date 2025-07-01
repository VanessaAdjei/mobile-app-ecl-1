# COD Payment Integration

## Overview
This document describes the Cash on Delivery (COD) payment integration for the ECL mobile app.

## API Endpoint
- **URL**: `https://eclcommerce.ernestchemists.com.gh/api/pay-on-delivery`
- **Method**: POST
- **Content-Type**: application/json

## Request Parameters
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `fname` | string | Yes | Customer's first name |
| `email` | string | Yes | Customer's email address |
| `phone` | string | Yes | Customer's phone number |
| `amount` | string | Yes | Order total amount (formatted to 2 decimal places) |

## Request Headers
- `Accept: application/json`
- `Content-Type: application/json`
- `Authorization: Bearer {token}` (if user is authenticated)

## Example Request
```json
{
  "fname": "John",
  "email": "john@example.com",
  "phone": "+233244123123",
  "amount": "150.00"
}
```

## Response Format
### Success Response (200/201)
```json
{
  "success": true,
  "data": {
    // API response data
  },
  "message": "COD payment processed successfully"
}
```

### Error Response
```json
{
  "success": false,
  "message": "Error description",
  "error_code": "ERROR_TYPE"
}
```

## Error Codes
- `UNAUTHORIZED` - Authentication required
- `VALIDATION_ERROR` - Invalid request parameters
- `SERVER_ERROR` - Server-side error
- `UNKNOWN_ERROR` - Unknown error
- `EXCEPTION` - Exception occurred

## Implementation Details

### Files Modified
1. **`lib/pages/auth_service.dart`** - Added CODPaymentService class
2. **`lib/pages/payment_page.dart`** - Updated to integrate COD payment API

### Key Features
- **Parameter Validation**: Validates all required parameters before making API call
- **Error Handling**: Comprehensive error handling for different scenarios
- **Loading States**: Proper loading indicators during payment processing
- **User Feedback**: Success/error messages for better UX
- **Debug Logging**: Detailed logging for troubleshooting

### Usage Flow
1. User selects "Cash on Delivery" payment method
2. System validates user data (name, email, phone, amount)
3. API call is made to `/pay-on-delivery` endpoint
4. Response is processed and appropriate feedback is shown
5. Order is created in the backend
6. User is redirected to order confirmation page

### Validation Rules
- **First Name**: Required, non-empty
- **Email**: Required, valid email format
- **Phone**: Required, valid phone number format
- **Amount**: Required, greater than 0

## Testing
To test the COD payment integration:

1. Add items to cart
2. Proceed to payment page
3. Select "Cash on Delivery" payment method
4. Click "PLACE ORDER (COD)" button
5. Verify API call is made with correct parameters
6. Check response handling and user feedback

## Debug Information
The service includes comprehensive debug logging:
- Request URL, headers, and body
- Response status, headers, and body
- Success/error scenarios
- Exception details

Check the debug console for detailed information during payment processing. 