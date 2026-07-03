import 'ad_model.dart';
import 'user_model.dart';

class FeedItem {
  final UserModel? profile;
  final AdModel? ad;

  FeedItem.fromProfile(UserModel p)
      : profile = p,
        ad = null;

  FeedItem.fromAd(AdModel a)
      : ad = a,
        profile = null;

  bool get isAd => ad != null;
}
