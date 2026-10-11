/// KalaSetu Route Constants
/// Section 10.3 of Project Specification
class RouteNames {
  RouteNames._();

  static const String splash = '/splash';
  static const String language = '/language';
  static const String onboarding = '/onboarding';
  
  static const String authPhone = '/auth/phone';
  static const String authOtp = '/auth/otp';
  static const String authProfile = '/auth/profile';

  static const String home = '/home';
  static const String homeCatalogue = '/home/catalogue';
  static const String homeAdd = '/home/add';
  static const String homeOrders = '/home/orders';
  static const String homeProfile = '/home/profile';

  static const String productDetail = '/product/:id';
  static const String productEdit = '/product/:id/edit';

  static const String addStudio = '/add/studio';
  static const String photoEditor = '/studio/editor';
  static const String addDescribe = '/add/describe';
  static const String addPrice = '/add/price';
  static const String addReview = '/add/review';

  static const String orderDetail = '/orders/:id';
  static const String orderTrack = '/order/track/:id';
  static const String marketplace = '/marketplace';
  static const String assistant = '/assistant';
  
  // Debug Route
  static const String gallery = '/gallery';

  // Analytics and Notifications
  static const String analytics = '/analytics';
  static const String notifications = '/notifications';

  // Simple Mode & Specialized Flows
  static const String simpleAdd = '/add/simple';
  static const String publishedSuccess = '/product/published-success';
  static const String fairMode = '/fair-mode';
  static const String businessOrders = '/orders/business';
  static const String marketplaces = '/marketplaces';
  static const String earnings = '/earnings';

  // Desktop Dashboard Routes
  static const String dashboard = '/dashboard';
  static const String dashboardProducts = '/dashboard/products';
  static const String dashboardOrders = '/dashboard/orders';
  static const String dashboardAnalytics = '/dashboard/analytics';
}
