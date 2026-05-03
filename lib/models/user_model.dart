/// Model data pengguna untuk autentikasi dan penyimpanan profil.
class UserModel {
  int? id;
  String name;
  String email;
  String password;
  String? photoUrl;
  int isBiometricEnabled;

  UserModel({
    this.id,
    required this.name,
    required this.email,
    required this.password,
    this.photoUrl,
    this.isBiometricEnabled = 0,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'email': email,
    'password': password,
    'photoUrl': photoUrl,
    'isBiometricEnabled': isBiometricEnabled,
  };

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
    id: map['id'],
    name: map['name'],
    email: map['email'],
    password: map['password'],
    photoUrl: map['photoUrl'],
    isBiometricEnabled: map['isBiometricEnabled'] ?? 0,
  );
}
