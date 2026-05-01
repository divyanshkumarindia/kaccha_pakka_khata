/// Subscription plan tiers for Kaccha Pakka Khata.
///
/// The hierarchy is: free < pro < premium.
/// A higher plan always includes all features of lower plans.
enum SubscriptionPlan {
  free,
  pro,
  premium;

  /// Returns true if this plan is at least as high as [other].
  bool isAtLeast(SubscriptionPlan other) => index >= other.index;
}

/// Every feature that can be gated behind a subscription.
///
/// Each feature maps to a minimum [SubscriptionPlan] required to access it.
enum Feature {
  // --- Pro Features ---
  downloadPdfExcel,
  printReports,
  noAds,
  unlimitedKhatas,
  unlimitedReportHistory,

  // --- Premium Features ---
  cloudBackup,
  multiCurrency,
  multiDeviceSync,
  customPdfBranding,
  prioritySupport,
  unlimitedSavedReports,
}

/// Maps each [Feature] to the minimum [SubscriptionPlan] needed to access it.
const Map<Feature, SubscriptionPlan> featureMinimumPlan = {
  // Pro tier
  Feature.downloadPdfExcel: SubscriptionPlan.pro,
  Feature.printReports: SubscriptionPlan.pro,
  Feature.noAds: SubscriptionPlan.pro,
  Feature.unlimitedKhatas: SubscriptionPlan.pro,
  Feature.unlimitedReportHistory: SubscriptionPlan.pro,

  // Premium tier
  Feature.cloudBackup: SubscriptionPlan.premium,
  Feature.multiCurrency: SubscriptionPlan.premium,
  Feature.multiDeviceSync: SubscriptionPlan.premium,
  Feature.customPdfBranding: SubscriptionPlan.premium,
  Feature.prioritySupport: SubscriptionPlan.premium,
  Feature.unlimitedSavedReports: SubscriptionPlan.premium,
};

/// Human-readable label for each feature (used in paywall upsell dialogs).
const Map<Feature, String> featureDisplayName = {
  Feature.downloadPdfExcel: 'Download PDF & Excel',
  Feature.printReports: 'Print Reports',
  Feature.noAds: 'Ad-Free Experience',
  Feature.unlimitedKhatas: 'Unlimited Khatas',
  Feature.unlimitedReportHistory: 'Unlimited Report History',
  Feature.cloudBackup: 'Cloud Backup & Restore',
  Feature.multiCurrency: 'Multi-Currency Support',
  Feature.multiDeviceSync: 'Multi-Device Sync',
  Feature.customPdfBranding: 'Custom PDF Branding (Logo)',
  Feature.prioritySupport: 'Priority Support',
  Feature.unlimitedSavedReports: 'Unlimited Saved Reports',
};

/// Numeric limits per plan for countable resources.
class PlanLimits {
  static int maxKhatas(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        return 2;
      case SubscriptionPlan.pro:
      case SubscriptionPlan.premium:
        return 999; // Effectively unlimited
    }
  }

  static int maxSavedReports(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        return 5;
      case SubscriptionPlan.pro:
        return 50;
      case SubscriptionPlan.premium:
        return 999; // Effectively unlimited
    }
  }

  /// Number of days of report history accessible.
  /// Returns -1 for unlimited.
  static int reportHistoryDays(SubscriptionPlan plan) {
    switch (plan) {
      case SubscriptionPlan.free:
        return 30;
      case SubscriptionPlan.pro:
      case SubscriptionPlan.premium:
        return -1; // Unlimited
    }
  }
}
