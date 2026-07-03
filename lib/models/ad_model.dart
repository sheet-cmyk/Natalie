class AdModel {
  final String uid;
  String name;
  int age;
  String bio;
  String whatsapp;
  String facebook;
  String tiktok;
  String instagram;
  List<String> photoUrls;
  bool published;

  AdModel({
    required this.uid,
    this.name = '',
    this.age = 0,
    this.bio = '',
    this.whatsapp = '',
    this.facebook = '',
    this.tiktok = '',
    this.instagram = '',
    this.photoUrls = const [],
    this.published = false,
  });

  bool get isComplete =>
      name.isNotEmpty && age > 0 && bio.isNotEmpty && photoUrls.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'name': name,
        'age': age,
        'bio': bio,
        'whatsapp': whatsapp,
        'facebook': facebook,
        'tiktok': tiktok,
        'instagram': instagram,
        'photoUrls': photoUrls,
        'published': published,
      };

  factory AdModel.fromMap(String uid, Map<String, dynamic> map) => AdModel(
        uid: uid,
        name: map['name'] as String? ?? '',
        age: map['age'] is int
            ? map['age'] as int
            : int.tryParse(map['age']?.toString() ?? '') ?? 0,
        bio: map['bio'] as String? ?? '',
        whatsapp: map['whatsapp'] as String? ?? '',
        facebook: map['facebook'] as String? ?? '',
        tiktok: map['tiktok'] as String? ?? '',
        instagram: map['instagram'] as String? ?? '',
        photoUrls: List<String>.from(map['photoUrls'] as List? ?? []),
        published: map['published'] as bool? ?? false,
      );
}
