# 🏪 Admin Dashboard - OmniaSA

## **📋 Overview**

A comprehensive admin dashboard for managing the OmniaSA platform. Built with Flutter for web/desktop, providing powerful tools for platform administration, seller management, and financial oversight.

## **🚀 Features**

### **👥 User Management**
- **Customer Management**: View, edit, and manage customer accounts
- **Seller Management**: Approve, suspend, and manage seller accounts
- **Role Management**: Assign admin, seller, and customer roles
- **Account Deletion**: Secure user deletion with data cleanup

### **💰 Financial Management**
- **Payout Management**: Review and approve seller payout requests
- **EFT Reconciliation**: Process bank statements and match payments
- **Financial Reports**: Track platform revenue and seller earnings
- **Payment Status**: Monitor order payment statuses

### **📦 Order Management**
- **Order Overview**: View all orders with filtering and search
- **Status Updates**: Update order statuses and track delivery
- **Return Management**: Process customer return requests
- **Order Analytics**: Track order trends and performance

### **🏪 Store Management**
- **Store Approval**: Review and approve new store applications
- **Store Monitoring**: Track store performance and compliance
- **Category Management**: Manage product categories
- **Store Analytics**: Performance metrics and insights

### **📊 Analytics & Reporting**
- **Platform Metrics**: User growth, order volume, revenue
- **Seller Performance**: Top performers and growth trends
- **Customer Insights**: Behavior analysis and preferences
- **System Health**: Performance monitoring and error tracking

## **🛠 Technical Stack**

- **Frontend**: Flutter Web/Desktop
- **Backend**: Firebase Firestore
- **Authentication**: Firebase Auth with custom claims
- **Cloud Functions**: Node.js backend services
- **State Management**: Provider pattern
- **Responsive Design**: Works on all screen sizes

## **🚀 Getting Started**

### **Prerequisites**
- Flutter 3.16.0+
- Firebase project setup
- Admin access credentials

### **Installation**
```bash
# Navigate to admin dashboard
cd admin_dashboard

# Install dependencies
flutter pub get

# Run in Chrome (recommended)
flutter run -d chrome

# Or run on desktop
flutter run -d windows  # Windows
flutter run -d macos    # macOS
flutter run -d linux    # Linux
```

### **Firebase Setup**
1. Ensure Firebase project is configured
2. Verify admin user has proper custom claims
3. Check Firestore security rules
4. Deploy Cloud Functions if needed

## **🔐 Admin Access**

### **Required Permissions**
- **Custom Claims**: `admin: true` or `role: 'admin'`
- **Firestore Access**: Read/write access to admin collections
- **Cloud Functions**: Access to admin-only functions

### **Security Features**
- **Role-based Access**: Admin-only features protected
- **Audit Logging**: All admin actions tracked
- **Data Validation**: Input sanitization and validation
- **Secure Deletion**: Proper data cleanup procedures

## **📁 Project Structure**

```
lib/
├── main.dart                    # Dashboard entry point
├── admin_dashboard_screen.dart  # Main dashboard layout
├── widgets/                     # Dashboard components
│   ├── admin_dashboard_content.dart
│   ├── user_management_table.dart
│   ├── admin_payouts_section.dart
│   ├── returns_management.dart
│   └── sellers_section.dart
├── theme/                       # Admin theme
│   └── admin_theme.dart
└── utils/                       # Utilities
    └── responsive_utils.dart
```

## **🎯 Key Workflows**

### **Seller Approval Process**
1. Seller submits application
2. Admin reviews store details
3. Admin approves/rejects application
4. Seller receives notification
5. Store goes live on platform

### **Payout Approval Process**
1. Seller requests payout
2. System locks available amount
3. Admin reviews payout request
4. Admin approves/rejects
5. Payment processed or amount unlocked

### **Return Management Process**
1. Customer submits return request
2. Admin reviews return details
3. Admin approves/rejects return
4. If approved: refund processed, seller balance adjusted
5. If rejected: return closed, no impact on seller

## **📊 Monitoring & Analytics**

### **Real-time Metrics**
- **Active Users**: Current platform usage
- **Order Volume**: Live order tracking
- **Revenue Tracking**: Platform earnings
- **System Performance**: Response times and errors

### **Reports Available**
- **Daily/Weekly/Monthly**: Time-based analytics
- **Seller Performance**: Individual store metrics
- **Category Analysis**: Product category trends
- **Geographic Insights**: Regional performance data

## **🔧 Configuration**

### **Environment Variables**
- **Firebase Config**: Project settings
- **Admin Settings**: Dashboard configuration
- **Feature Flags**: Enable/disable features
- **API Keys**: External service integrations

### **Customization Options**
- **Theme Colors**: Brand customization
- **Dashboard Layout**: Widget arrangement
- **Notification Settings**: Alert preferences
- **Export Formats**: Data export options

## **🚀 Deployment**

### **Production Checklist**
- [ ] All admin features tested
- [ ] Security rules verified
- [ ] Cloud Functions deployed
- [ ] Admin users configured
- [ ] Monitoring setup
- [ ] Backup procedures

### **Build Commands**
```bash
# Web deployment
flutter build web --release

# Desktop builds
flutter build windows --release
flutter build macos --release
flutter build linux --release
```

## **📞 Support**

### **Technical Issues**
- **Documentation**: Check this README first
- **Firebase Console**: Verify project configuration
- **Cloud Functions**: Check function logs
- **GitHub Issues**: Report bugs and feature requests

### **Admin Training**
- **User Guide**: Step-by-step admin procedures
- **Video Tutorials**: Visual walkthroughs
- **Best Practices**: Recommended workflows
- **Security Guidelines**: Admin security protocols

---

**Built for OmniaSA Administration** 🏪

*This dashboard provides comprehensive platform management capabilities with a focus on security, usability, and performance.*
