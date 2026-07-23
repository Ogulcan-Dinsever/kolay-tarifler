import Flutter
import UIKit
import google_mobile_ads

private final class InFeedNativeAdFactory: NSObject, FLTNativeAdFactory {
  private static let mediaSize: CGFloat = 120
  private static let cardHeight: CGFloat = 136

  func createNativeAd(
    _ nativeAd: NativeAd,
    customOptions: [AnyHashable: Any]? = nil
  ) -> NativeAdView? {
    let isDark = customOptions?["isDark"] as? Bool ?? false
    let background = isDark
      ? UIColor(red: 29 / 255, green: 45 / 255, blue: 61 / 255, alpha: 1)
      : .white
    let primaryText = isDark
      ? UIColor(red: 243 / 255, green: 244 / 255, blue: 246 / 255, alpha: 1)
      : UIColor(red: 23 / 255, green: 32 / 255, blue: 51 / 255, alpha: 1)
    let secondaryText = isDark
      ? UIColor(red: 169 / 255, green: 180 / 255, blue: 195 / 255, alpha: 1)
      : UIColor(red: 102 / 255, green: 112 / 255, blue: 133 / 255, alpha: 1)

    let adView = NativeAdView()
    adView.backgroundColor = background
    adView.layer.cornerRadius = 12
    adView.clipsToBounds = true

    let mediaView = MediaView()
    mediaView.translatesAutoresizingMaskIntoConstraints = false
    adView.addSubview(mediaView)
    adView.mediaView = mediaView
    mediaView.mediaContent = nativeAd.mediaContent

    let attribution = UILabel()
    attribution.text = "Reklam"
    attribution.font = .boldSystemFont(ofSize: 10)
    attribution.textColor = secondaryText

    let headline = UILabel()
    headline.text = nativeAd.headline
    headline.font = .boldSystemFont(ofSize: 15)
    headline.textColor = primaryText
    headline.numberOfLines = 1
    adView.headlineView = headline

    let body = UILabel()
    body.text = nativeAd.body
    body.font = .systemFont(ofSize: 12)
    body.textColor = secondaryText
    body.numberOfLines = 2
    body.isHidden = nativeAd.body == nil
    adView.bodyView = body

    let callToAction = UIButton(type: .system)
    callToAction.setTitle(nativeAd.callToAction, for: .normal)
    callToAction.setTitleColor(.white, for: .normal)
    callToAction.titleLabel?.font = .boldSystemFont(ofSize: 13)
    callToAction.backgroundColor = UIColor(
      red: 22 / 255, green: 200 / 255, blue: 109 / 255, alpha: 1)
    callToAction.layer.cornerRadius = 8
    callToAction.isHidden = nativeAd.callToAction == nil
    callToAction.isUserInteractionEnabled = false
    adView.callToActionView = callToAction

    let details = UIStackView(arrangedSubviews: [
      attribution, headline, body, callToAction,
    ])
    details.axis = .vertical
    details.spacing = 2
    details.translatesAutoresizingMaskIntoConstraints = false
    adView.addSubview(details)

    NSLayoutConstraint.activate([
      adView.heightAnchor.constraint(equalToConstant: Self.cardHeight),
      mediaView.leadingAnchor.constraint(equalTo: adView.leadingAnchor, constant: 8),
      mediaView.topAnchor.constraint(equalTo: adView.topAnchor, constant: 8),
      mediaView.widthAnchor.constraint(equalToConstant: Self.mediaSize),
      mediaView.heightAnchor.constraint(equalToConstant: Self.mediaSize),
      details.leadingAnchor.constraint(equalTo: mediaView.trailingAnchor, constant: 10),
      details.trailingAnchor.constraint(equalTo: adView.trailingAnchor, constant: -8),
      details.topAnchor.constraint(equalTo: adView.topAnchor, constant: 8),
      details.bottomAnchor.constraint(equalTo: adView.bottomAnchor, constant: -8),
      callToAction.heightAnchor.constraint(equalToConstant: 34),
    ])

    // Set this last so the SDK can register all clickable asset views.
    adView.nativeAd = nativeAd
    return adView
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    FLTGoogleMobileAdsPlugin.registerNativeAdFactory(
      engineBridge.pluginRegistry,
      factoryId: "inFeed",
      nativeAdFactory: InFeedNativeAdFactory()
    )
  }
}
