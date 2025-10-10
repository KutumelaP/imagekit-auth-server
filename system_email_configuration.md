# 📧 OmniaSA Email Configuration

## Email Accounts & Usage

### **admin@omniasa.co.za** - System Emails
**Purpose**: Automated system emails, order notifications, system alerts
**Used for**:
- ✅ Order confirmations
- ✅ Payment notifications  
- ✅ Delivery updates
- ✅ Password reset emails
- ✅ System alerts
- ✅ Automated notifications

### **support@omniasa.co.za** - Customer Support
**Purpose**: Human-to-human customer support
**Used for**:
- ✅ Customer inquiries
- ✅ Support chat
- ✅ Manual support requests
- ✅ Customer complaints
- ✅ General questions

## Server Configuration
- **Domain**: omniasa.co.za
- **Email Server**: lowkey.aserv.co.za
- **Protocol**: IMAP over SSL/TLS (Recommended)

### Incoming Mail (IMAP)
- **Server**: lowkey.aserv.co.za
- **Port**: 993
- **Security**: SSL/TLS
- **Authentication**: Required

### Outgoing Mail (SMTP)
- **Server**: lowkey.aserv.co.za
- **Port**: 465
- **Security**: SSL/TLS
- **Authentication**: Required

## Firebase Functions Configuration
Set these environment variables in Firebase:
```bash
MAIL_FROM=admin@omniasa.co.za
SUPPORT_EMAIL=support@omniasa.co.za
```

## Email Flow
1. **System emails** → admin@omniasa.co.za
2. **Customer support** → support@omniasa.co.za
3. **Admin notifications** → admin@omniasa.co.za

## Next Steps
1. **Set passwords** for both email accounts
2. **Configure Firebase environment variables**
3. **Test email functionality**
4. **Set up email forwarding** if needed








