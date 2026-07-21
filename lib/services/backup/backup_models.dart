class BackupCandidate {
  final String id;
  final String name;
  final String position;
  final String className;
  final String section;
  final String rollNumber;
  final String? photoFile;
  final int votes;
  final String createdAt;

  const BackupCandidate({
    required this.id,
    required this.name,
    required this.position,
    required this.className,
    required this.section,
    required this.rollNumber,
    this.photoFile,
    required this.votes,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'position': position,
    'className': className,
    'section': section,
    'rollNumber': rollNumber,
    'photoFile': photoFile,
    'votes': votes,
    'createdAt': createdAt,
  };

  factory BackupCandidate.fromJson(Map<String, dynamic> json) =>
      BackupCandidate(
        id: json['id'] as String,
        name: json['name'] as String,
        position: json['position'] as String,
        className: json['className'] as String,
        section: json['section'] as String,
        rollNumber: json['rollNumber'] as String,
        photoFile: json['photoFile'] as String?,
        votes: json['votes'] as int? ?? 0,
        createdAt: json['createdAt'] as String? ?? '',
      );
}

class BackupVote {
  final String key;
  final dynamic value;

  const BackupVote({required this.key, required this.value});

  Map<String, dynamic> toJson() => {'key': key, 'value': value};

  factory BackupVote.fromJson(Map<String, dynamic> json) =>
      BackupVote(key: json['key'] as String, value: json['value']);
}

class BackupConfig {
  final String schoolName;
  final String academicYear;
  final String? logoUrl;

  const BackupConfig({
    required this.schoolName,
    required this.academicYear,
    this.logoUrl,
  });

  Map<String, dynamic> toJson() => {
    'schoolName': schoolName,
    'academicYear': academicYear,
    'logoUrl': logoUrl,
  };

  factory BackupConfig.fromJson(Map<String, dynamic> json) => BackupConfig(
    schoolName: json['schoolName'] as String? ?? '',
    academicYear: json['academicYear'] as String? ?? '',
    logoUrl: json['logoUrl'] as String?,
  );
}

class BackupData {
  final int version;
  final String createdAt;
  final List<BackupCandidate> candidates;
  final List<BackupVote> votes;
  final BackupConfig appConfig;

  const BackupData({
    required this.version,
    required this.createdAt,
    required this.candidates,
    required this.votes,
    required this.appConfig,
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'createdAt': createdAt,
    'candidates': candidates.map((c) => c.toJson()).toList(),
    'votes': votes.map((v) => v.toJson()).toList(),
    'appConfig': appConfig.toJson(),
  };

  factory BackupData.fromJson(Map<String, dynamic> json) => BackupData(
    version: json['version'] as int? ?? 1,
    createdAt: json['createdAt'] as String? ?? '',
    candidates: (json['candidates'] as List<dynamic>?)
            ?.map((e) => BackupCandidate.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    votes: (json['votes'] as List<dynamic>?)
            ?.map((e) => BackupVote.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [],
    appConfig: json['appConfig'] != null
        ? BackupConfig.fromJson(json['appConfig'] as Map<String, dynamic>)
        : const BackupConfig(schoolName: '', academicYear: ''),
  );
}
