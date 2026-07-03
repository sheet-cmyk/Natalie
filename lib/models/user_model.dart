class UserModel {
  final String uid;
  final String email;
  String name;
  int age;
  String bio;
  String whatsapp;
  String facebook;
  String tiktok;
  String instagram;
  List<String> photoUrls;
  bool published;

  UserModel({
    required this.uid,
    required this.email,
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
        'email': email,
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

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) => UserModel(
        uid: uid,
        email: map['email'] ?? '',
        name: map['name'] ?? '',
        age: map['age'] is int
            ? map['age'] as int
            : int.tryParse(map['age']?.toString() ?? '') ?? 0,
        bio: map['bio'] ?? '',
        whatsapp: map['whatsapp'] ?? '',
        facebook: map['facebook'] ?? '',
        tiktok: map['tiktok'] ?? '',
        instagram: map['instagram'] ?? '',
        photoUrls: List<String>.from(map['photoUrls'] ?? []),
        published: map['published'] ?? false,
      );
}
