// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $MetaBaseTable extends MetaBase
    with TableInfo<$MetaBaseTable, MetaBaseData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetaBaseTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cleMeta = const VerificationMeta('cle');
  @override
  late final GeneratedColumn<String> cle = GeneratedColumn<String>(
    'cle',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valeurMeta = const VerificationMeta('valeur');
  @override
  late final GeneratedColumn<String> valeur = GeneratedColumn<String>(
    'valeur',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _misAJourLeMeta = const VerificationMeta(
    'misAJourLe',
  );
  @override
  late final GeneratedColumn<DateTime> misAJourLe = GeneratedColumn<DateTime>(
    'mis_a_jour_le',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [cle, valeur, misAJourLe];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meta_base';
  @override
  VerificationContext validateIntegrity(
    Insertable<MetaBaseData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cle')) {
      context.handle(
        _cleMeta,
        cle.isAcceptableOrUnknown(data['cle']!, _cleMeta),
      );
    } else if (isInserting) {
      context.missing(_cleMeta);
    }
    if (data.containsKey('valeur')) {
      context.handle(
        _valeurMeta,
        valeur.isAcceptableOrUnknown(data['valeur']!, _valeurMeta),
      );
    } else if (isInserting) {
      context.missing(_valeurMeta);
    }
    if (data.containsKey('mis_a_jour_le')) {
      context.handle(
        _misAJourLeMeta,
        misAJourLe.isAcceptableOrUnknown(
          data['mis_a_jour_le']!,
          _misAJourLeMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cle};
  @override
  MetaBaseData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetaBaseData(
      cle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cle'],
      )!,
      valeur: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}valeur'],
      )!,
      misAJourLe: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}mis_a_jour_le'],
      )!,
    );
  }

  @override
  $MetaBaseTable createAlias(String alias) {
    return $MetaBaseTable(attachedDatabase, alias);
  }
}

class MetaBaseData extends DataClass implements Insertable<MetaBaseData> {
  final String cle;
  final String valeur;
  final DateTime misAJourLe;
  const MetaBaseData({
    required this.cle,
    required this.valeur,
    required this.misAJourLe,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cle'] = Variable<String>(cle);
    map['valeur'] = Variable<String>(valeur);
    map['mis_a_jour_le'] = Variable<DateTime>(misAJourLe);
    return map;
  }

  MetaBaseCompanion toCompanion(bool nullToAbsent) {
    return MetaBaseCompanion(
      cle: Value(cle),
      valeur: Value(valeur),
      misAJourLe: Value(misAJourLe),
    );
  }

  factory MetaBaseData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetaBaseData(
      cle: serializer.fromJson<String>(json['cle']),
      valeur: serializer.fromJson<String>(json['valeur']),
      misAJourLe: serializer.fromJson<DateTime>(json['misAJourLe']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cle': serializer.toJson<String>(cle),
      'valeur': serializer.toJson<String>(valeur),
      'misAJourLe': serializer.toJson<DateTime>(misAJourLe),
    };
  }

  MetaBaseData copyWith({String? cle, String? valeur, DateTime? misAJourLe}) =>
      MetaBaseData(
        cle: cle ?? this.cle,
        valeur: valeur ?? this.valeur,
        misAJourLe: misAJourLe ?? this.misAJourLe,
      );
  MetaBaseData copyWithCompanion(MetaBaseCompanion data) {
    return MetaBaseData(
      cle: data.cle.present ? data.cle.value : this.cle,
      valeur: data.valeur.present ? data.valeur.value : this.valeur,
      misAJourLe: data.misAJourLe.present
          ? data.misAJourLe.value
          : this.misAJourLe,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetaBaseData(')
          ..write('cle: $cle, ')
          ..write('valeur: $valeur, ')
          ..write('misAJourLe: $misAJourLe')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(cle, valeur, misAJourLe);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MetaBaseData &&
          other.cle == this.cle &&
          other.valeur == this.valeur &&
          other.misAJourLe == this.misAJourLe);
}

class MetaBaseCompanion extends UpdateCompanion<MetaBaseData> {
  final Value<String> cle;
  final Value<String> valeur;
  final Value<DateTime> misAJourLe;
  final Value<int> rowid;
  const MetaBaseCompanion({
    this.cle = const Value.absent(),
    this.valeur = const Value.absent(),
    this.misAJourLe = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MetaBaseCompanion.insert({
    required String cle,
    required String valeur,
    this.misAJourLe = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : cle = Value(cle),
       valeur = Value(valeur);
  static Insertable<MetaBaseData> custom({
    Expression<String>? cle,
    Expression<String>? valeur,
    Expression<DateTime>? misAJourLe,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cle != null) 'cle': cle,
      if (valeur != null) 'valeur': valeur,
      if (misAJourLe != null) 'mis_a_jour_le': misAJourLe,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MetaBaseCompanion copyWith({
    Value<String>? cle,
    Value<String>? valeur,
    Value<DateTime>? misAJourLe,
    Value<int>? rowid,
  }) {
    return MetaBaseCompanion(
      cle: cle ?? this.cle,
      valeur: valeur ?? this.valeur,
      misAJourLe: misAJourLe ?? this.misAJourLe,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cle.present) {
      map['cle'] = Variable<String>(cle.value);
    }
    if (valeur.present) {
      map['valeur'] = Variable<String>(valeur.value);
    }
    if (misAJourLe.present) {
      map['mis_a_jour_le'] = Variable<DateTime>(misAJourLe.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MetaBaseCompanion(')
          ..write('cle: $cle, ')
          ..write('valeur: $valeur, ')
          ..write('misAJourLe: $misAJourLe, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ArticlesLocauxTable extends ArticlesLocaux
    with TableInfo<$ArticlesLocauxTable, ArticleLocal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ArticlesLocauxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codeAs400Meta = const VerificationMeta(
    'codeAs400',
  );
  @override
  late final GeneratedColumn<String> codeAs400 = GeneratedColumn<String>(
    'code_as400',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _libelleMeta = const VerificationMeta(
    'libelle',
  );
  @override
  late final GeneratedColumn<String> libelle = GeneratedColumn<String>(
    'libelle',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gencodeMeta = const VerificationMeta(
    'gencode',
  );
  @override
  late final GeneratedColumn<String> gencode = GeneratedColumn<String>(
    'gencode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _marqueMeta = const VerificationMeta('marque');
  @override
  late final GeneratedColumn<String> marque = GeneratedColumn<String>(
    'marque',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _familleMeta = const VerificationMeta(
    'famille',
  );
  @override
  late final GeneratedColumn<String> famille = GeneratedColumn<String>(
    'famille',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gammeMeta = const VerificationMeta('gamme');
  @override
  late final GeneratedColumn<String> gamme = GeneratedColumn<String>(
    'gamme',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeArticleMeta = const VerificationMeta(
    'typeArticle',
  );
  @override
  late final GeneratedColumn<String> typeArticle = GeneratedColumn<String>(
    'type_article',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statutMeta = const VerificationMeta('statut');
  @override
  late final GeneratedColumn<String> statut = GeneratedColumn<String>(
    'statut',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pcbMeta = const VerificationMeta('pcb');
  @override
  late final GeneratedColumn<int> pcb = GeneratedColumn<int>(
    'pcb',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stockMeta = const VerificationMeta('stock');
  @override
  late final GeneratedColumn<int> stock = GeneratedColumn<int>(
    'stock',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _actifMeta = const VerificationMeta('actif');
  @override
  late final GeneratedColumn<bool> actif = GeneratedColumn<bool>(
    'actif',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("actif" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _prixMeta = const VerificationMeta('prix');
  @override
  late final GeneratedColumn<double> prix = GeneratedColumn<double>(
    'prix',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enPromoMeta = const VerificationMeta(
    'enPromo',
  );
  @override
  late final GeneratedColumn<bool> enPromo = GeneratedColumn<bool>(
    'en_promo',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("en_promo" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _promoLibelleMeta = const VerificationMeta(
    'promoLibelle',
  );
  @override
  late final GeneratedColumn<String> promoLibelle = GeneratedColumn<String>(
    'promo_libelle',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _misEnAvantMeta = const VerificationMeta(
    'misEnAvant',
  );
  @override
  late final GeneratedColumn<bool> misEnAvant = GeneratedColumn<bool>(
    'mis_en_avant',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("mis_en_avant" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    codeAs400,
    libelle,
    gencode,
    marque,
    famille,
    gamme,
    typeArticle,
    statut,
    pcb,
    stock,
    actif,
    prix,
    enPromo,
    promoLibelle,
    misEnAvant,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'articles_locaux';
  @override
  VerificationContext validateIntegrity(
    Insertable<ArticleLocal> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('code_as400')) {
      context.handle(
        _codeAs400Meta,
        codeAs400.isAcceptableOrUnknown(data['code_as400']!, _codeAs400Meta),
      );
    } else if (isInserting) {
      context.missing(_codeAs400Meta);
    }
    if (data.containsKey('libelle')) {
      context.handle(
        _libelleMeta,
        libelle.isAcceptableOrUnknown(data['libelle']!, _libelleMeta),
      );
    } else if (isInserting) {
      context.missing(_libelleMeta);
    }
    if (data.containsKey('gencode')) {
      context.handle(
        _gencodeMeta,
        gencode.isAcceptableOrUnknown(data['gencode']!, _gencodeMeta),
      );
    }
    if (data.containsKey('marque')) {
      context.handle(
        _marqueMeta,
        marque.isAcceptableOrUnknown(data['marque']!, _marqueMeta),
      );
    }
    if (data.containsKey('famille')) {
      context.handle(
        _familleMeta,
        famille.isAcceptableOrUnknown(data['famille']!, _familleMeta),
      );
    }
    if (data.containsKey('gamme')) {
      context.handle(
        _gammeMeta,
        gamme.isAcceptableOrUnknown(data['gamme']!, _gammeMeta),
      );
    }
    if (data.containsKey('type_article')) {
      context.handle(
        _typeArticleMeta,
        typeArticle.isAcceptableOrUnknown(
          data['type_article']!,
          _typeArticleMeta,
        ),
      );
    }
    if (data.containsKey('statut')) {
      context.handle(
        _statutMeta,
        statut.isAcceptableOrUnknown(data['statut']!, _statutMeta),
      );
    }
    if (data.containsKey('pcb')) {
      context.handle(
        _pcbMeta,
        pcb.isAcceptableOrUnknown(data['pcb']!, _pcbMeta),
      );
    }
    if (data.containsKey('stock')) {
      context.handle(
        _stockMeta,
        stock.isAcceptableOrUnknown(data['stock']!, _stockMeta),
      );
    }
    if (data.containsKey('actif')) {
      context.handle(
        _actifMeta,
        actif.isAcceptableOrUnknown(data['actif']!, _actifMeta),
      );
    }
    if (data.containsKey('prix')) {
      context.handle(
        _prixMeta,
        prix.isAcceptableOrUnknown(data['prix']!, _prixMeta),
      );
    }
    if (data.containsKey('en_promo')) {
      context.handle(
        _enPromoMeta,
        enPromo.isAcceptableOrUnknown(data['en_promo']!, _enPromoMeta),
      );
    }
    if (data.containsKey('promo_libelle')) {
      context.handle(
        _promoLibelleMeta,
        promoLibelle.isAcceptableOrUnknown(
          data['promo_libelle']!,
          _promoLibelleMeta,
        ),
      );
    }
    if (data.containsKey('mis_en_avant')) {
      context.handle(
        _misEnAvantMeta,
        misEnAvant.isAcceptableOrUnknown(
          data['mis_en_avant']!,
          _misEnAvantMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ArticleLocal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ArticleLocal(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      codeAs400: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code_as400'],
      )!,
      libelle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}libelle'],
      )!,
      gencode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gencode'],
      ),
      marque: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}marque'],
      ),
      famille: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}famille'],
      ),
      gamme: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gamme'],
      ),
      typeArticle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type_article'],
      ),
      statut: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}statut'],
      ),
      pcb: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pcb'],
      ),
      stock: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stock'],
      )!,
      actif: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}actif'],
      )!,
      prix: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}prix'],
      ),
      enPromo: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}en_promo'],
      )!,
      promoLibelle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}promo_libelle'],
      ),
      misEnAvant: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}mis_en_avant'],
      )!,
    );
  }

  @override
  $ArticlesLocauxTable createAlias(String alias) {
    return $ArticlesLocauxTable(attachedDatabase, alias);
  }
}

class ArticleLocal extends DataClass implements Insertable<ArticleLocal> {
  /// Identifiant serveur (UUID).
  final String id;
  final String codeAs400;
  final String libelle;
  final String? gencode;
  final String? marque;
  final String? famille;
  final String? gamme;
  final String? typeArticle;
  final String? statut;
  final int? pcb;
  final int stock;
  final bool actif;

  /// Prix indicatif HT (premier tarif).
  final double? prix;
  final bool enPromo;
  final String? promoLibelle;
  final bool misEnAvant;
  const ArticleLocal({
    required this.id,
    required this.codeAs400,
    required this.libelle,
    this.gencode,
    this.marque,
    this.famille,
    this.gamme,
    this.typeArticle,
    this.statut,
    this.pcb,
    required this.stock,
    required this.actif,
    this.prix,
    required this.enPromo,
    this.promoLibelle,
    required this.misEnAvant,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['code_as400'] = Variable<String>(codeAs400);
    map['libelle'] = Variable<String>(libelle);
    if (!nullToAbsent || gencode != null) {
      map['gencode'] = Variable<String>(gencode);
    }
    if (!nullToAbsent || marque != null) {
      map['marque'] = Variable<String>(marque);
    }
    if (!nullToAbsent || famille != null) {
      map['famille'] = Variable<String>(famille);
    }
    if (!nullToAbsent || gamme != null) {
      map['gamme'] = Variable<String>(gamme);
    }
    if (!nullToAbsent || typeArticle != null) {
      map['type_article'] = Variable<String>(typeArticle);
    }
    if (!nullToAbsent || statut != null) {
      map['statut'] = Variable<String>(statut);
    }
    if (!nullToAbsent || pcb != null) {
      map['pcb'] = Variable<int>(pcb);
    }
    map['stock'] = Variable<int>(stock);
    map['actif'] = Variable<bool>(actif);
    if (!nullToAbsent || prix != null) {
      map['prix'] = Variable<double>(prix);
    }
    map['en_promo'] = Variable<bool>(enPromo);
    if (!nullToAbsent || promoLibelle != null) {
      map['promo_libelle'] = Variable<String>(promoLibelle);
    }
    map['mis_en_avant'] = Variable<bool>(misEnAvant);
    return map;
  }

  ArticlesLocauxCompanion toCompanion(bool nullToAbsent) {
    return ArticlesLocauxCompanion(
      id: Value(id),
      codeAs400: Value(codeAs400),
      libelle: Value(libelle),
      gencode: gencode == null && nullToAbsent
          ? const Value.absent()
          : Value(gencode),
      marque: marque == null && nullToAbsent
          ? const Value.absent()
          : Value(marque),
      famille: famille == null && nullToAbsent
          ? const Value.absent()
          : Value(famille),
      gamme: gamme == null && nullToAbsent
          ? const Value.absent()
          : Value(gamme),
      typeArticle: typeArticle == null && nullToAbsent
          ? const Value.absent()
          : Value(typeArticle),
      statut: statut == null && nullToAbsent
          ? const Value.absent()
          : Value(statut),
      pcb: pcb == null && nullToAbsent ? const Value.absent() : Value(pcb),
      stock: Value(stock),
      actif: Value(actif),
      prix: prix == null && nullToAbsent ? const Value.absent() : Value(prix),
      enPromo: Value(enPromo),
      promoLibelle: promoLibelle == null && nullToAbsent
          ? const Value.absent()
          : Value(promoLibelle),
      misEnAvant: Value(misEnAvant),
    );
  }

  factory ArticleLocal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ArticleLocal(
      id: serializer.fromJson<String>(json['id']),
      codeAs400: serializer.fromJson<String>(json['codeAs400']),
      libelle: serializer.fromJson<String>(json['libelle']),
      gencode: serializer.fromJson<String?>(json['gencode']),
      marque: serializer.fromJson<String?>(json['marque']),
      famille: serializer.fromJson<String?>(json['famille']),
      gamme: serializer.fromJson<String?>(json['gamme']),
      typeArticle: serializer.fromJson<String?>(json['typeArticle']),
      statut: serializer.fromJson<String?>(json['statut']),
      pcb: serializer.fromJson<int?>(json['pcb']),
      stock: serializer.fromJson<int>(json['stock']),
      actif: serializer.fromJson<bool>(json['actif']),
      prix: serializer.fromJson<double?>(json['prix']),
      enPromo: serializer.fromJson<bool>(json['enPromo']),
      promoLibelle: serializer.fromJson<String?>(json['promoLibelle']),
      misEnAvant: serializer.fromJson<bool>(json['misEnAvant']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'codeAs400': serializer.toJson<String>(codeAs400),
      'libelle': serializer.toJson<String>(libelle),
      'gencode': serializer.toJson<String?>(gencode),
      'marque': serializer.toJson<String?>(marque),
      'famille': serializer.toJson<String?>(famille),
      'gamme': serializer.toJson<String?>(gamme),
      'typeArticle': serializer.toJson<String?>(typeArticle),
      'statut': serializer.toJson<String?>(statut),
      'pcb': serializer.toJson<int?>(pcb),
      'stock': serializer.toJson<int>(stock),
      'actif': serializer.toJson<bool>(actif),
      'prix': serializer.toJson<double?>(prix),
      'enPromo': serializer.toJson<bool>(enPromo),
      'promoLibelle': serializer.toJson<String?>(promoLibelle),
      'misEnAvant': serializer.toJson<bool>(misEnAvant),
    };
  }

  ArticleLocal copyWith({
    String? id,
    String? codeAs400,
    String? libelle,
    Value<String?> gencode = const Value.absent(),
    Value<String?> marque = const Value.absent(),
    Value<String?> famille = const Value.absent(),
    Value<String?> gamme = const Value.absent(),
    Value<String?> typeArticle = const Value.absent(),
    Value<String?> statut = const Value.absent(),
    Value<int?> pcb = const Value.absent(),
    int? stock,
    bool? actif,
    Value<double?> prix = const Value.absent(),
    bool? enPromo,
    Value<String?> promoLibelle = const Value.absent(),
    bool? misEnAvant,
  }) => ArticleLocal(
    id: id ?? this.id,
    codeAs400: codeAs400 ?? this.codeAs400,
    libelle: libelle ?? this.libelle,
    gencode: gencode.present ? gencode.value : this.gencode,
    marque: marque.present ? marque.value : this.marque,
    famille: famille.present ? famille.value : this.famille,
    gamme: gamme.present ? gamme.value : this.gamme,
    typeArticle: typeArticle.present ? typeArticle.value : this.typeArticle,
    statut: statut.present ? statut.value : this.statut,
    pcb: pcb.present ? pcb.value : this.pcb,
    stock: stock ?? this.stock,
    actif: actif ?? this.actif,
    prix: prix.present ? prix.value : this.prix,
    enPromo: enPromo ?? this.enPromo,
    promoLibelle: promoLibelle.present ? promoLibelle.value : this.promoLibelle,
    misEnAvant: misEnAvant ?? this.misEnAvant,
  );
  ArticleLocal copyWithCompanion(ArticlesLocauxCompanion data) {
    return ArticleLocal(
      id: data.id.present ? data.id.value : this.id,
      codeAs400: data.codeAs400.present ? data.codeAs400.value : this.codeAs400,
      libelle: data.libelle.present ? data.libelle.value : this.libelle,
      gencode: data.gencode.present ? data.gencode.value : this.gencode,
      marque: data.marque.present ? data.marque.value : this.marque,
      famille: data.famille.present ? data.famille.value : this.famille,
      gamme: data.gamme.present ? data.gamme.value : this.gamme,
      typeArticle: data.typeArticle.present
          ? data.typeArticle.value
          : this.typeArticle,
      statut: data.statut.present ? data.statut.value : this.statut,
      pcb: data.pcb.present ? data.pcb.value : this.pcb,
      stock: data.stock.present ? data.stock.value : this.stock,
      actif: data.actif.present ? data.actif.value : this.actif,
      prix: data.prix.present ? data.prix.value : this.prix,
      enPromo: data.enPromo.present ? data.enPromo.value : this.enPromo,
      promoLibelle: data.promoLibelle.present
          ? data.promoLibelle.value
          : this.promoLibelle,
      misEnAvant: data.misEnAvant.present
          ? data.misEnAvant.value
          : this.misEnAvant,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ArticleLocal(')
          ..write('id: $id, ')
          ..write('codeAs400: $codeAs400, ')
          ..write('libelle: $libelle, ')
          ..write('gencode: $gencode, ')
          ..write('marque: $marque, ')
          ..write('famille: $famille, ')
          ..write('gamme: $gamme, ')
          ..write('typeArticle: $typeArticle, ')
          ..write('statut: $statut, ')
          ..write('pcb: $pcb, ')
          ..write('stock: $stock, ')
          ..write('actif: $actif, ')
          ..write('prix: $prix, ')
          ..write('enPromo: $enPromo, ')
          ..write('promoLibelle: $promoLibelle, ')
          ..write('misEnAvant: $misEnAvant')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    codeAs400,
    libelle,
    gencode,
    marque,
    famille,
    gamme,
    typeArticle,
    statut,
    pcb,
    stock,
    actif,
    prix,
    enPromo,
    promoLibelle,
    misEnAvant,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ArticleLocal &&
          other.id == this.id &&
          other.codeAs400 == this.codeAs400 &&
          other.libelle == this.libelle &&
          other.gencode == this.gencode &&
          other.marque == this.marque &&
          other.famille == this.famille &&
          other.gamme == this.gamme &&
          other.typeArticle == this.typeArticle &&
          other.statut == this.statut &&
          other.pcb == this.pcb &&
          other.stock == this.stock &&
          other.actif == this.actif &&
          other.prix == this.prix &&
          other.enPromo == this.enPromo &&
          other.promoLibelle == this.promoLibelle &&
          other.misEnAvant == this.misEnAvant);
}

class ArticlesLocauxCompanion extends UpdateCompanion<ArticleLocal> {
  final Value<String> id;
  final Value<String> codeAs400;
  final Value<String> libelle;
  final Value<String?> gencode;
  final Value<String?> marque;
  final Value<String?> famille;
  final Value<String?> gamme;
  final Value<String?> typeArticle;
  final Value<String?> statut;
  final Value<int?> pcb;
  final Value<int> stock;
  final Value<bool> actif;
  final Value<double?> prix;
  final Value<bool> enPromo;
  final Value<String?> promoLibelle;
  final Value<bool> misEnAvant;
  final Value<int> rowid;
  const ArticlesLocauxCompanion({
    this.id = const Value.absent(),
    this.codeAs400 = const Value.absent(),
    this.libelle = const Value.absent(),
    this.gencode = const Value.absent(),
    this.marque = const Value.absent(),
    this.famille = const Value.absent(),
    this.gamme = const Value.absent(),
    this.typeArticle = const Value.absent(),
    this.statut = const Value.absent(),
    this.pcb = const Value.absent(),
    this.stock = const Value.absent(),
    this.actif = const Value.absent(),
    this.prix = const Value.absent(),
    this.enPromo = const Value.absent(),
    this.promoLibelle = const Value.absent(),
    this.misEnAvant = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ArticlesLocauxCompanion.insert({
    required String id,
    required String codeAs400,
    required String libelle,
    this.gencode = const Value.absent(),
    this.marque = const Value.absent(),
    this.famille = const Value.absent(),
    this.gamme = const Value.absent(),
    this.typeArticle = const Value.absent(),
    this.statut = const Value.absent(),
    this.pcb = const Value.absent(),
    this.stock = const Value.absent(),
    this.actif = const Value.absent(),
    this.prix = const Value.absent(),
    this.enPromo = const Value.absent(),
    this.promoLibelle = const Value.absent(),
    this.misEnAvant = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       codeAs400 = Value(codeAs400),
       libelle = Value(libelle);
  static Insertable<ArticleLocal> custom({
    Expression<String>? id,
    Expression<String>? codeAs400,
    Expression<String>? libelle,
    Expression<String>? gencode,
    Expression<String>? marque,
    Expression<String>? famille,
    Expression<String>? gamme,
    Expression<String>? typeArticle,
    Expression<String>? statut,
    Expression<int>? pcb,
    Expression<int>? stock,
    Expression<bool>? actif,
    Expression<double>? prix,
    Expression<bool>? enPromo,
    Expression<String>? promoLibelle,
    Expression<bool>? misEnAvant,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (codeAs400 != null) 'code_as400': codeAs400,
      if (libelle != null) 'libelle': libelle,
      if (gencode != null) 'gencode': gencode,
      if (marque != null) 'marque': marque,
      if (famille != null) 'famille': famille,
      if (gamme != null) 'gamme': gamme,
      if (typeArticle != null) 'type_article': typeArticle,
      if (statut != null) 'statut': statut,
      if (pcb != null) 'pcb': pcb,
      if (stock != null) 'stock': stock,
      if (actif != null) 'actif': actif,
      if (prix != null) 'prix': prix,
      if (enPromo != null) 'en_promo': enPromo,
      if (promoLibelle != null) 'promo_libelle': promoLibelle,
      if (misEnAvant != null) 'mis_en_avant': misEnAvant,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ArticlesLocauxCompanion copyWith({
    Value<String>? id,
    Value<String>? codeAs400,
    Value<String>? libelle,
    Value<String?>? gencode,
    Value<String?>? marque,
    Value<String?>? famille,
    Value<String?>? gamme,
    Value<String?>? typeArticle,
    Value<String?>? statut,
    Value<int?>? pcb,
    Value<int>? stock,
    Value<bool>? actif,
    Value<double?>? prix,
    Value<bool>? enPromo,
    Value<String?>? promoLibelle,
    Value<bool>? misEnAvant,
    Value<int>? rowid,
  }) {
    return ArticlesLocauxCompanion(
      id: id ?? this.id,
      codeAs400: codeAs400 ?? this.codeAs400,
      libelle: libelle ?? this.libelle,
      gencode: gencode ?? this.gencode,
      marque: marque ?? this.marque,
      famille: famille ?? this.famille,
      gamme: gamme ?? this.gamme,
      typeArticle: typeArticle ?? this.typeArticle,
      statut: statut ?? this.statut,
      pcb: pcb ?? this.pcb,
      stock: stock ?? this.stock,
      actif: actif ?? this.actif,
      prix: prix ?? this.prix,
      enPromo: enPromo ?? this.enPromo,
      promoLibelle: promoLibelle ?? this.promoLibelle,
      misEnAvant: misEnAvant ?? this.misEnAvant,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (codeAs400.present) {
      map['code_as400'] = Variable<String>(codeAs400.value);
    }
    if (libelle.present) {
      map['libelle'] = Variable<String>(libelle.value);
    }
    if (gencode.present) {
      map['gencode'] = Variable<String>(gencode.value);
    }
    if (marque.present) {
      map['marque'] = Variable<String>(marque.value);
    }
    if (famille.present) {
      map['famille'] = Variable<String>(famille.value);
    }
    if (gamme.present) {
      map['gamme'] = Variable<String>(gamme.value);
    }
    if (typeArticle.present) {
      map['type_article'] = Variable<String>(typeArticle.value);
    }
    if (statut.present) {
      map['statut'] = Variable<String>(statut.value);
    }
    if (pcb.present) {
      map['pcb'] = Variable<int>(pcb.value);
    }
    if (stock.present) {
      map['stock'] = Variable<int>(stock.value);
    }
    if (actif.present) {
      map['actif'] = Variable<bool>(actif.value);
    }
    if (prix.present) {
      map['prix'] = Variable<double>(prix.value);
    }
    if (enPromo.present) {
      map['en_promo'] = Variable<bool>(enPromo.value);
    }
    if (promoLibelle.present) {
      map['promo_libelle'] = Variable<String>(promoLibelle.value);
    }
    if (misEnAvant.present) {
      map['mis_en_avant'] = Variable<bool>(misEnAvant.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ArticlesLocauxCompanion(')
          ..write('id: $id, ')
          ..write('codeAs400: $codeAs400, ')
          ..write('libelle: $libelle, ')
          ..write('gencode: $gencode, ')
          ..write('marque: $marque, ')
          ..write('famille: $famille, ')
          ..write('gamme: $gamme, ')
          ..write('typeArticle: $typeArticle, ')
          ..write('statut: $statut, ')
          ..write('pcb: $pcb, ')
          ..write('stock: $stock, ')
          ..write('actif: $actif, ')
          ..write('prix: $prix, ')
          ..write('enPromo: $enPromo, ')
          ..write('promoLibelle: $promoLibelle, ')
          ..write('misEnAvant: $misEnAvant, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ClientsLocauxTable extends ClientsLocaux
    with TableInfo<$ClientsLocauxTable, ClientLocal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ClientsLocauxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codeAs400Meta = const VerificationMeta(
    'codeAs400',
  );
  @override
  late final GeneratedColumn<String> codeAs400 = GeneratedColumn<String>(
    'code_as400',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enseigneMeta = const VerificationMeta(
    'enseigne',
  );
  @override
  late final GeneratedColumn<String> enseigne = GeneratedColumn<String>(
    'enseigne',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _raisonSocialeMeta = const VerificationMeta(
    'raisonSociale',
  );
  @override
  late final GeneratedColumn<String> raisonSociale = GeneratedColumn<String>(
    'raison_sociale',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _adresse1Meta = const VerificationMeta(
    'adresse1',
  );
  @override
  late final GeneratedColumn<String> adresse1 = GeneratedColumn<String>(
    'adresse1',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _codePostalMeta = const VerificationMeta(
    'codePostal',
  );
  @override
  late final GeneratedColumn<String> codePostal = GeneratedColumn<String>(
    'code_postal',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _villeMeta = const VerificationMeta('ville');
  @override
  late final GeneratedColumn<String> ville = GeneratedColumn<String>(
    'ville',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _telephoneMeta = const VerificationMeta(
    'telephone',
  );
  @override
  late final GeneratedColumn<String> telephone = GeneratedColumn<String>(
    'telephone',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contactMeta = const VerificationMeta(
    'contact',
  );
  @override
  late final GeneratedColumn<String> contact = GeneratedColumn<String>(
    'contact',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _actifMeta = const VerificationMeta('actif');
  @override
  late final GeneratedColumn<bool> actif = GeneratedColumn<bool>(
    'actif',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("actif" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _niveauClassMeta = const VerificationMeta(
    'niveauClass',
  );
  @override
  late final GeneratedColumn<String> niveauClass = GeneratedColumn<String>(
    'niveau_class',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    codeAs400,
    enseigne,
    raisonSociale,
    adresse1,
    codePostal,
    ville,
    telephone,
    contact,
    actif,
    niveauClass,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'clients_locaux';
  @override
  VerificationContext validateIntegrity(
    Insertable<ClientLocal> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('code_as400')) {
      context.handle(
        _codeAs400Meta,
        codeAs400.isAcceptableOrUnknown(data['code_as400']!, _codeAs400Meta),
      );
    } else if (isInserting) {
      context.missing(_codeAs400Meta);
    }
    if (data.containsKey('enseigne')) {
      context.handle(
        _enseigneMeta,
        enseigne.isAcceptableOrUnknown(data['enseigne']!, _enseigneMeta),
      );
    } else if (isInserting) {
      context.missing(_enseigneMeta);
    }
    if (data.containsKey('raison_sociale')) {
      context.handle(
        _raisonSocialeMeta,
        raisonSociale.isAcceptableOrUnknown(
          data['raison_sociale']!,
          _raisonSocialeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_raisonSocialeMeta);
    }
    if (data.containsKey('adresse1')) {
      context.handle(
        _adresse1Meta,
        adresse1.isAcceptableOrUnknown(data['adresse1']!, _adresse1Meta),
      );
    }
    if (data.containsKey('code_postal')) {
      context.handle(
        _codePostalMeta,
        codePostal.isAcceptableOrUnknown(data['code_postal']!, _codePostalMeta),
      );
    }
    if (data.containsKey('ville')) {
      context.handle(
        _villeMeta,
        ville.isAcceptableOrUnknown(data['ville']!, _villeMeta),
      );
    }
    if (data.containsKey('telephone')) {
      context.handle(
        _telephoneMeta,
        telephone.isAcceptableOrUnknown(data['telephone']!, _telephoneMeta),
      );
    }
    if (data.containsKey('contact')) {
      context.handle(
        _contactMeta,
        contact.isAcceptableOrUnknown(data['contact']!, _contactMeta),
      );
    }
    if (data.containsKey('actif')) {
      context.handle(
        _actifMeta,
        actif.isAcceptableOrUnknown(data['actif']!, _actifMeta),
      );
    }
    if (data.containsKey('niveau_class')) {
      context.handle(
        _niveauClassMeta,
        niveauClass.isAcceptableOrUnknown(
          data['niveau_class']!,
          _niveauClassMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ClientLocal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ClientLocal(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      codeAs400: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code_as400'],
      )!,
      enseigne: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}enseigne'],
      )!,
      raisonSociale: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}raison_sociale'],
      )!,
      adresse1: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}adresse1'],
      ),
      codePostal: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code_postal'],
      ),
      ville: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ville'],
      ),
      telephone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}telephone'],
      ),
      contact: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact'],
      ),
      actif: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}actif'],
      )!,
      niveauClass: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}niveau_class'],
      ),
    );
  }

  @override
  $ClientsLocauxTable createAlias(String alias) {
    return $ClientsLocauxTable(attachedDatabase, alias);
  }
}

class ClientLocal extends DataClass implements Insertable<ClientLocal> {
  /// Identifiant serveur (UUID).
  final String id;
  final String codeAs400;
  final String enseigne;
  final String raisonSociale;
  final String? adresse1;
  final String? codePostal;
  final String? ville;
  final String? telephone;
  final String? contact;
  final bool actif;

  /// Classe CRM de A à G, nulle si non classé.
  final String? niveauClass;
  const ClientLocal({
    required this.id,
    required this.codeAs400,
    required this.enseigne,
    required this.raisonSociale,
    this.adresse1,
    this.codePostal,
    this.ville,
    this.telephone,
    this.contact,
    required this.actif,
    this.niveauClass,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['code_as400'] = Variable<String>(codeAs400);
    map['enseigne'] = Variable<String>(enseigne);
    map['raison_sociale'] = Variable<String>(raisonSociale);
    if (!nullToAbsent || adresse1 != null) {
      map['adresse1'] = Variable<String>(adresse1);
    }
    if (!nullToAbsent || codePostal != null) {
      map['code_postal'] = Variable<String>(codePostal);
    }
    if (!nullToAbsent || ville != null) {
      map['ville'] = Variable<String>(ville);
    }
    if (!nullToAbsent || telephone != null) {
      map['telephone'] = Variable<String>(telephone);
    }
    if (!nullToAbsent || contact != null) {
      map['contact'] = Variable<String>(contact);
    }
    map['actif'] = Variable<bool>(actif);
    if (!nullToAbsent || niveauClass != null) {
      map['niveau_class'] = Variable<String>(niveauClass);
    }
    return map;
  }

  ClientsLocauxCompanion toCompanion(bool nullToAbsent) {
    return ClientsLocauxCompanion(
      id: Value(id),
      codeAs400: Value(codeAs400),
      enseigne: Value(enseigne),
      raisonSociale: Value(raisonSociale),
      adresse1: adresse1 == null && nullToAbsent
          ? const Value.absent()
          : Value(adresse1),
      codePostal: codePostal == null && nullToAbsent
          ? const Value.absent()
          : Value(codePostal),
      ville: ville == null && nullToAbsent
          ? const Value.absent()
          : Value(ville),
      telephone: telephone == null && nullToAbsent
          ? const Value.absent()
          : Value(telephone),
      contact: contact == null && nullToAbsent
          ? const Value.absent()
          : Value(contact),
      actif: Value(actif),
      niveauClass: niveauClass == null && nullToAbsent
          ? const Value.absent()
          : Value(niveauClass),
    );
  }

  factory ClientLocal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ClientLocal(
      id: serializer.fromJson<String>(json['id']),
      codeAs400: serializer.fromJson<String>(json['codeAs400']),
      enseigne: serializer.fromJson<String>(json['enseigne']),
      raisonSociale: serializer.fromJson<String>(json['raisonSociale']),
      adresse1: serializer.fromJson<String?>(json['adresse1']),
      codePostal: serializer.fromJson<String?>(json['codePostal']),
      ville: serializer.fromJson<String?>(json['ville']),
      telephone: serializer.fromJson<String?>(json['telephone']),
      contact: serializer.fromJson<String?>(json['contact']),
      actif: serializer.fromJson<bool>(json['actif']),
      niveauClass: serializer.fromJson<String?>(json['niveauClass']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'codeAs400': serializer.toJson<String>(codeAs400),
      'enseigne': serializer.toJson<String>(enseigne),
      'raisonSociale': serializer.toJson<String>(raisonSociale),
      'adresse1': serializer.toJson<String?>(adresse1),
      'codePostal': serializer.toJson<String?>(codePostal),
      'ville': serializer.toJson<String?>(ville),
      'telephone': serializer.toJson<String?>(telephone),
      'contact': serializer.toJson<String?>(contact),
      'actif': serializer.toJson<bool>(actif),
      'niveauClass': serializer.toJson<String?>(niveauClass),
    };
  }

  ClientLocal copyWith({
    String? id,
    String? codeAs400,
    String? enseigne,
    String? raisonSociale,
    Value<String?> adresse1 = const Value.absent(),
    Value<String?> codePostal = const Value.absent(),
    Value<String?> ville = const Value.absent(),
    Value<String?> telephone = const Value.absent(),
    Value<String?> contact = const Value.absent(),
    bool? actif,
    Value<String?> niveauClass = const Value.absent(),
  }) => ClientLocal(
    id: id ?? this.id,
    codeAs400: codeAs400 ?? this.codeAs400,
    enseigne: enseigne ?? this.enseigne,
    raisonSociale: raisonSociale ?? this.raisonSociale,
    adresse1: adresse1.present ? adresse1.value : this.adresse1,
    codePostal: codePostal.present ? codePostal.value : this.codePostal,
    ville: ville.present ? ville.value : this.ville,
    telephone: telephone.present ? telephone.value : this.telephone,
    contact: contact.present ? contact.value : this.contact,
    actif: actif ?? this.actif,
    niveauClass: niveauClass.present ? niveauClass.value : this.niveauClass,
  );
  ClientLocal copyWithCompanion(ClientsLocauxCompanion data) {
    return ClientLocal(
      id: data.id.present ? data.id.value : this.id,
      codeAs400: data.codeAs400.present ? data.codeAs400.value : this.codeAs400,
      enseigne: data.enseigne.present ? data.enseigne.value : this.enseigne,
      raisonSociale: data.raisonSociale.present
          ? data.raisonSociale.value
          : this.raisonSociale,
      adresse1: data.adresse1.present ? data.adresse1.value : this.adresse1,
      codePostal: data.codePostal.present
          ? data.codePostal.value
          : this.codePostal,
      ville: data.ville.present ? data.ville.value : this.ville,
      telephone: data.telephone.present ? data.telephone.value : this.telephone,
      contact: data.contact.present ? data.contact.value : this.contact,
      actif: data.actif.present ? data.actif.value : this.actif,
      niveauClass: data.niveauClass.present
          ? data.niveauClass.value
          : this.niveauClass,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ClientLocal(')
          ..write('id: $id, ')
          ..write('codeAs400: $codeAs400, ')
          ..write('enseigne: $enseigne, ')
          ..write('raisonSociale: $raisonSociale, ')
          ..write('adresse1: $adresse1, ')
          ..write('codePostal: $codePostal, ')
          ..write('ville: $ville, ')
          ..write('telephone: $telephone, ')
          ..write('contact: $contact, ')
          ..write('actif: $actif, ')
          ..write('niveauClass: $niveauClass')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    codeAs400,
    enseigne,
    raisonSociale,
    adresse1,
    codePostal,
    ville,
    telephone,
    contact,
    actif,
    niveauClass,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ClientLocal &&
          other.id == this.id &&
          other.codeAs400 == this.codeAs400 &&
          other.enseigne == this.enseigne &&
          other.raisonSociale == this.raisonSociale &&
          other.adresse1 == this.adresse1 &&
          other.codePostal == this.codePostal &&
          other.ville == this.ville &&
          other.telephone == this.telephone &&
          other.contact == this.contact &&
          other.actif == this.actif &&
          other.niveauClass == this.niveauClass);
}

class ClientsLocauxCompanion extends UpdateCompanion<ClientLocal> {
  final Value<String> id;
  final Value<String> codeAs400;
  final Value<String> enseigne;
  final Value<String> raisonSociale;
  final Value<String?> adresse1;
  final Value<String?> codePostal;
  final Value<String?> ville;
  final Value<String?> telephone;
  final Value<String?> contact;
  final Value<bool> actif;
  final Value<String?> niveauClass;
  final Value<int> rowid;
  const ClientsLocauxCompanion({
    this.id = const Value.absent(),
    this.codeAs400 = const Value.absent(),
    this.enseigne = const Value.absent(),
    this.raisonSociale = const Value.absent(),
    this.adresse1 = const Value.absent(),
    this.codePostal = const Value.absent(),
    this.ville = const Value.absent(),
    this.telephone = const Value.absent(),
    this.contact = const Value.absent(),
    this.actif = const Value.absent(),
    this.niveauClass = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ClientsLocauxCompanion.insert({
    required String id,
    required String codeAs400,
    required String enseigne,
    required String raisonSociale,
    this.adresse1 = const Value.absent(),
    this.codePostal = const Value.absent(),
    this.ville = const Value.absent(),
    this.telephone = const Value.absent(),
    this.contact = const Value.absent(),
    this.actif = const Value.absent(),
    this.niveauClass = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       codeAs400 = Value(codeAs400),
       enseigne = Value(enseigne),
       raisonSociale = Value(raisonSociale);
  static Insertable<ClientLocal> custom({
    Expression<String>? id,
    Expression<String>? codeAs400,
    Expression<String>? enseigne,
    Expression<String>? raisonSociale,
    Expression<String>? adresse1,
    Expression<String>? codePostal,
    Expression<String>? ville,
    Expression<String>? telephone,
    Expression<String>? contact,
    Expression<bool>? actif,
    Expression<String>? niveauClass,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (codeAs400 != null) 'code_as400': codeAs400,
      if (enseigne != null) 'enseigne': enseigne,
      if (raisonSociale != null) 'raison_sociale': raisonSociale,
      if (adresse1 != null) 'adresse1': adresse1,
      if (codePostal != null) 'code_postal': codePostal,
      if (ville != null) 'ville': ville,
      if (telephone != null) 'telephone': telephone,
      if (contact != null) 'contact': contact,
      if (actif != null) 'actif': actif,
      if (niveauClass != null) 'niveau_class': niveauClass,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ClientsLocauxCompanion copyWith({
    Value<String>? id,
    Value<String>? codeAs400,
    Value<String>? enseigne,
    Value<String>? raisonSociale,
    Value<String?>? adresse1,
    Value<String?>? codePostal,
    Value<String?>? ville,
    Value<String?>? telephone,
    Value<String?>? contact,
    Value<bool>? actif,
    Value<String?>? niveauClass,
    Value<int>? rowid,
  }) {
    return ClientsLocauxCompanion(
      id: id ?? this.id,
      codeAs400: codeAs400 ?? this.codeAs400,
      enseigne: enseigne ?? this.enseigne,
      raisonSociale: raisonSociale ?? this.raisonSociale,
      adresse1: adresse1 ?? this.adresse1,
      codePostal: codePostal ?? this.codePostal,
      ville: ville ?? this.ville,
      telephone: telephone ?? this.telephone,
      contact: contact ?? this.contact,
      actif: actif ?? this.actif,
      niveauClass: niveauClass ?? this.niveauClass,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (codeAs400.present) {
      map['code_as400'] = Variable<String>(codeAs400.value);
    }
    if (enseigne.present) {
      map['enseigne'] = Variable<String>(enseigne.value);
    }
    if (raisonSociale.present) {
      map['raison_sociale'] = Variable<String>(raisonSociale.value);
    }
    if (adresse1.present) {
      map['adresse1'] = Variable<String>(adresse1.value);
    }
    if (codePostal.present) {
      map['code_postal'] = Variable<String>(codePostal.value);
    }
    if (ville.present) {
      map['ville'] = Variable<String>(ville.value);
    }
    if (telephone.present) {
      map['telephone'] = Variable<String>(telephone.value);
    }
    if (contact.present) {
      map['contact'] = Variable<String>(contact.value);
    }
    if (actif.present) {
      map['actif'] = Variable<bool>(actif.value);
    }
    if (niveauClass.present) {
      map['niveau_class'] = Variable<String>(niveauClass.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ClientsLocauxCompanion(')
          ..write('id: $id, ')
          ..write('codeAs400: $codeAs400, ')
          ..write('enseigne: $enseigne, ')
          ..write('raisonSociale: $raisonSociale, ')
          ..write('adresse1: $adresse1, ')
          ..write('codePostal: $codePostal, ')
          ..write('ville: $ville, ')
          ..write('telephone: $telephone, ')
          ..write('contact: $contact, ')
          ..write('actif: $actif, ')
          ..write('niveauClass: $niveauClass, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EnregistrementsLocauxTable extends EnregistrementsLocaux
    with TableInfo<$EnregistrementsLocauxTable, EnregistrementLocal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EnregistrementsLocauxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _domaineMeta = const VerificationMeta(
    'domaine',
  );
  @override
  late final GeneratedColumn<String> domaine = GeneratedColumn<String>(
    'domaine',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
    'json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [domaine, id, json];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'enregistrements_locaux';
  @override
  VerificationContext validateIntegrity(
    Insertable<EnregistrementLocal> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('domaine')) {
      context.handle(
        _domaineMeta,
        domaine.isAcceptableOrUnknown(data['domaine']!, _domaineMeta),
      );
    } else if (isInserting) {
      context.missing(_domaineMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
        _jsonMeta,
        json.isAcceptableOrUnknown(data['json']!, _jsonMeta),
      );
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {domaine, id};
  @override
  EnregistrementLocal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EnregistrementLocal(
      domaine: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}domaine'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      json: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}json'],
      )!,
    );
  }

  @override
  $EnregistrementsLocauxTable createAlias(String alias) {
    return $EnregistrementsLocauxTable(attachedDatabase, alias);
  }
}

class EnregistrementLocal extends DataClass
    implements Insertable<EnregistrementLocal> {
  final String domaine;
  final String id;

  /// Ligne telle que renvoyée par l'API.
  final String json;
  const EnregistrementLocal({
    required this.domaine,
    required this.id,
    required this.json,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['domaine'] = Variable<String>(domaine);
    map['id'] = Variable<String>(id);
    map['json'] = Variable<String>(json);
    return map;
  }

  EnregistrementsLocauxCompanion toCompanion(bool nullToAbsent) {
    return EnregistrementsLocauxCompanion(
      domaine: Value(domaine),
      id: Value(id),
      json: Value(json),
    );
  }

  factory EnregistrementLocal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EnregistrementLocal(
      domaine: serializer.fromJson<String>(json['domaine']),
      id: serializer.fromJson<String>(json['id']),
      json: serializer.fromJson<String>(json['json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'domaine': serializer.toJson<String>(domaine),
      'id': serializer.toJson<String>(id),
      'json': serializer.toJson<String>(json),
    };
  }

  EnregistrementLocal copyWith({String? domaine, String? id, String? json}) =>
      EnregistrementLocal(
        domaine: domaine ?? this.domaine,
        id: id ?? this.id,
        json: json ?? this.json,
      );
  EnregistrementLocal copyWithCompanion(EnregistrementsLocauxCompanion data) {
    return EnregistrementLocal(
      domaine: data.domaine.present ? data.domaine.value : this.domaine,
      id: data.id.present ? data.id.value : this.id,
      json: data.json.present ? data.json.value : this.json,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EnregistrementLocal(')
          ..write('domaine: $domaine, ')
          ..write('id: $id, ')
          ..write('json: $json')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(domaine, id, json);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EnregistrementLocal &&
          other.domaine == this.domaine &&
          other.id == this.id &&
          other.json == this.json);
}

class EnregistrementsLocauxCompanion
    extends UpdateCompanion<EnregistrementLocal> {
  final Value<String> domaine;
  final Value<String> id;
  final Value<String> json;
  final Value<int> rowid;
  const EnregistrementsLocauxCompanion({
    this.domaine = const Value.absent(),
    this.id = const Value.absent(),
    this.json = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  EnregistrementsLocauxCompanion.insert({
    required String domaine,
    required String id,
    required String json,
    this.rowid = const Value.absent(),
  }) : domaine = Value(domaine),
       id = Value(id),
       json = Value(json);
  static Insertable<EnregistrementLocal> custom({
    Expression<String>? domaine,
    Expression<String>? id,
    Expression<String>? json,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (domaine != null) 'domaine': domaine,
      if (id != null) 'id': id,
      if (json != null) 'json': json,
      if (rowid != null) 'rowid': rowid,
    });
  }

  EnregistrementsLocauxCompanion copyWith({
    Value<String>? domaine,
    Value<String>? id,
    Value<String>? json,
    Value<int>? rowid,
  }) {
    return EnregistrementsLocauxCompanion(
      domaine: domaine ?? this.domaine,
      id: id ?? this.id,
      json: json ?? this.json,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (domaine.present) {
      map['domaine'] = Variable<String>(domaine.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EnregistrementsLocauxCompanion(')
          ..write('domaine: $domaine, ')
          ..write('id: $id, ')
          ..write('json: $json, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PhotosLocalesTable extends PhotosLocales
    with TableInfo<$PhotosLocalesTable, PhotoLocale> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhotosLocalesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _octetsMeta = const VerificationMeta('octets');
  @override
  late final GeneratedColumn<Uint8List> octets = GeneratedColumn<Uint8List>(
    'octets',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _majLeMeta = const VerificationMeta('majLe');
  @override
  late final GeneratedColumn<DateTime> majLe = GeneratedColumn<DateTime>(
    'maj_le',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, octets, majLe];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'photos_locales';
  @override
  VerificationContext validateIntegrity(
    Insertable<PhotoLocale> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('octets')) {
      context.handle(
        _octetsMeta,
        octets.isAcceptableOrUnknown(data['octets']!, _octetsMeta),
      );
    } else if (isInserting) {
      context.missing(_octetsMeta);
    }
    if (data.containsKey('maj_le')) {
      context.handle(
        _majLeMeta,
        majLe.isAcceptableOrUnknown(data['maj_le']!, _majLeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PhotoLocale map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PhotoLocale(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      octets: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}octets'],
      )!,
      majLe: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}maj_le'],
      )!,
    );
  }

  @override
  $PhotosLocalesTable createAlias(String alias) {
    return $PhotosLocalesTable(attachedDatabase, alias);
  }
}

class PhotoLocale extends DataClass implements Insertable<PhotoLocale> {
  final String id;
  final Uint8List octets;
  final DateTime majLe;
  const PhotoLocale({
    required this.id,
    required this.octets,
    required this.majLe,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['octets'] = Variable<Uint8List>(octets);
    map['maj_le'] = Variable<DateTime>(majLe);
    return map;
  }

  PhotosLocalesCompanion toCompanion(bool nullToAbsent) {
    return PhotosLocalesCompanion(
      id: Value(id),
      octets: Value(octets),
      majLe: Value(majLe),
    );
  }

  factory PhotoLocale.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PhotoLocale(
      id: serializer.fromJson<String>(json['id']),
      octets: serializer.fromJson<Uint8List>(json['octets']),
      majLe: serializer.fromJson<DateTime>(json['majLe']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'octets': serializer.toJson<Uint8List>(octets),
      'majLe': serializer.toJson<DateTime>(majLe),
    };
  }

  PhotoLocale copyWith({String? id, Uint8List? octets, DateTime? majLe}) =>
      PhotoLocale(
        id: id ?? this.id,
        octets: octets ?? this.octets,
        majLe: majLe ?? this.majLe,
      );
  PhotoLocale copyWithCompanion(PhotosLocalesCompanion data) {
    return PhotoLocale(
      id: data.id.present ? data.id.value : this.id,
      octets: data.octets.present ? data.octets.value : this.octets,
      majLe: data.majLe.present ? data.majLe.value : this.majLe,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PhotoLocale(')
          ..write('id: $id, ')
          ..write('octets: $octets, ')
          ..write('majLe: $majLe')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, $driftBlobEquality.hash(octets), majLe);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PhotoLocale &&
          other.id == this.id &&
          $driftBlobEquality.equals(other.octets, this.octets) &&
          other.majLe == this.majLe);
}

class PhotosLocalesCompanion extends UpdateCompanion<PhotoLocale> {
  final Value<String> id;
  final Value<Uint8List> octets;
  final Value<DateTime> majLe;
  final Value<int> rowid;
  const PhotosLocalesCompanion({
    this.id = const Value.absent(),
    this.octets = const Value.absent(),
    this.majLe = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PhotosLocalesCompanion.insert({
    required String id,
    required Uint8List octets,
    this.majLe = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       octets = Value(octets);
  static Insertable<PhotoLocale> custom({
    Expression<String>? id,
    Expression<Uint8List>? octets,
    Expression<DateTime>? majLe,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (octets != null) 'octets': octets,
      if (majLe != null) 'maj_le': majLe,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PhotosLocalesCompanion copyWith({
    Value<String>? id,
    Value<Uint8List>? octets,
    Value<DateTime>? majLe,
    Value<int>? rowid,
  }) {
    return PhotosLocalesCompanion(
      id: id ?? this.id,
      octets: octets ?? this.octets,
      majLe: majLe ?? this.majLe,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (octets.present) {
      map['octets'] = Variable<Uint8List>(octets.value);
    }
    if (majLe.present) {
      map['maj_le'] = Variable<DateTime>(majLe.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhotosLocalesCompanion(')
          ..write('id: $id, ')
          ..write('octets: $octets, ')
          ..write('majLe: $majLe, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PhotosVisiteTable extends PhotosVisite
    with TableInfo<$PhotosVisiteTable, PhotoVisiteLocale> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PhotosVisiteTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _visiteIdMeta = const VerificationMeta(
    'visiteId',
  );
  @override
  late final GeneratedColumn<String> visiteId = GeneratedColumn<String>(
    'visite_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _etapeMeta = const VerificationMeta('etape');
  @override
  late final GeneratedColumn<String> etape = GeneratedColumn<String>(
    'etape',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _octetsMeta = const VerificationMeta('octets');
  @override
  late final GeneratedColumn<Uint8List> octets = GeneratedColumn<Uint8List>(
    'octets',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priseLeMeta = const VerificationMeta(
    'priseLe',
  );
  @override
  late final GeneratedColumn<DateTime> priseLe = GeneratedColumn<DateTime>(
    'prise_le',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, visiteId, etape, octets, priseLe];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'photos_visite';
  @override
  VerificationContext validateIntegrity(
    Insertable<PhotoVisiteLocale> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('visite_id')) {
      context.handle(
        _visiteIdMeta,
        visiteId.isAcceptableOrUnknown(data['visite_id']!, _visiteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_visiteIdMeta);
    }
    if (data.containsKey('etape')) {
      context.handle(
        _etapeMeta,
        etape.isAcceptableOrUnknown(data['etape']!, _etapeMeta),
      );
    } else if (isInserting) {
      context.missing(_etapeMeta);
    }
    if (data.containsKey('octets')) {
      context.handle(
        _octetsMeta,
        octets.isAcceptableOrUnknown(data['octets']!, _octetsMeta),
      );
    } else if (isInserting) {
      context.missing(_octetsMeta);
    }
    if (data.containsKey('prise_le')) {
      context.handle(
        _priseLeMeta,
        priseLe.isAcceptableOrUnknown(data['prise_le']!, _priseLeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PhotoVisiteLocale map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PhotoVisiteLocale(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      visiteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}visite_id'],
      )!,
      etape: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etape'],
      )!,
      octets: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}octets'],
      )!,
      priseLe: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}prise_le'],
      )!,
    );
  }

  @override
  $PhotosVisiteTable createAlias(String alias) {
    return $PhotosVisiteTable(attachedDatabase, alias);
  }
}

class PhotoVisiteLocale extends DataClass
    implements Insertable<PhotoVisiteLocale> {
  final int id;

  /// Identifiant de la visite (celui de l'app).
  final String visiteId;

  /// Clé de l'étape (`EtapeDph.cle`).
  final String etape;
  final Uint8List octets;
  final DateTime priseLe;
  const PhotoVisiteLocale({
    required this.id,
    required this.visiteId,
    required this.etape,
    required this.octets,
    required this.priseLe,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['visite_id'] = Variable<String>(visiteId);
    map['etape'] = Variable<String>(etape);
    map['octets'] = Variable<Uint8List>(octets);
    map['prise_le'] = Variable<DateTime>(priseLe);
    return map;
  }

  PhotosVisiteCompanion toCompanion(bool nullToAbsent) {
    return PhotosVisiteCompanion(
      id: Value(id),
      visiteId: Value(visiteId),
      etape: Value(etape),
      octets: Value(octets),
      priseLe: Value(priseLe),
    );
  }

  factory PhotoVisiteLocale.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PhotoVisiteLocale(
      id: serializer.fromJson<int>(json['id']),
      visiteId: serializer.fromJson<String>(json['visiteId']),
      etape: serializer.fromJson<String>(json['etape']),
      octets: serializer.fromJson<Uint8List>(json['octets']),
      priseLe: serializer.fromJson<DateTime>(json['priseLe']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'visiteId': serializer.toJson<String>(visiteId),
      'etape': serializer.toJson<String>(etape),
      'octets': serializer.toJson<Uint8List>(octets),
      'priseLe': serializer.toJson<DateTime>(priseLe),
    };
  }

  PhotoVisiteLocale copyWith({
    int? id,
    String? visiteId,
    String? etape,
    Uint8List? octets,
    DateTime? priseLe,
  }) => PhotoVisiteLocale(
    id: id ?? this.id,
    visiteId: visiteId ?? this.visiteId,
    etape: etape ?? this.etape,
    octets: octets ?? this.octets,
    priseLe: priseLe ?? this.priseLe,
  );
  PhotoVisiteLocale copyWithCompanion(PhotosVisiteCompanion data) {
    return PhotoVisiteLocale(
      id: data.id.present ? data.id.value : this.id,
      visiteId: data.visiteId.present ? data.visiteId.value : this.visiteId,
      etape: data.etape.present ? data.etape.value : this.etape,
      octets: data.octets.present ? data.octets.value : this.octets,
      priseLe: data.priseLe.present ? data.priseLe.value : this.priseLe,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PhotoVisiteLocale(')
          ..write('id: $id, ')
          ..write('visiteId: $visiteId, ')
          ..write('etape: $etape, ')
          ..write('octets: $octets, ')
          ..write('priseLe: $priseLe')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    visiteId,
    etape,
    $driftBlobEquality.hash(octets),
    priseLe,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PhotoVisiteLocale &&
          other.id == this.id &&
          other.visiteId == this.visiteId &&
          other.etape == this.etape &&
          $driftBlobEquality.equals(other.octets, this.octets) &&
          other.priseLe == this.priseLe);
}

class PhotosVisiteCompanion extends UpdateCompanion<PhotoVisiteLocale> {
  final Value<int> id;
  final Value<String> visiteId;
  final Value<String> etape;
  final Value<Uint8List> octets;
  final Value<DateTime> priseLe;
  const PhotosVisiteCompanion({
    this.id = const Value.absent(),
    this.visiteId = const Value.absent(),
    this.etape = const Value.absent(),
    this.octets = const Value.absent(),
    this.priseLe = const Value.absent(),
  });
  PhotosVisiteCompanion.insert({
    this.id = const Value.absent(),
    required String visiteId,
    required String etape,
    required Uint8List octets,
    this.priseLe = const Value.absent(),
  }) : visiteId = Value(visiteId),
       etape = Value(etape),
       octets = Value(octets);
  static Insertable<PhotoVisiteLocale> custom({
    Expression<int>? id,
    Expression<String>? visiteId,
    Expression<String>? etape,
    Expression<Uint8List>? octets,
    Expression<DateTime>? priseLe,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (visiteId != null) 'visite_id': visiteId,
      if (etape != null) 'etape': etape,
      if (octets != null) 'octets': octets,
      if (priseLe != null) 'prise_le': priseLe,
    });
  }

  PhotosVisiteCompanion copyWith({
    Value<int>? id,
    Value<String>? visiteId,
    Value<String>? etape,
    Value<Uint8List>? octets,
    Value<DateTime>? priseLe,
  }) {
    return PhotosVisiteCompanion(
      id: id ?? this.id,
      visiteId: visiteId ?? this.visiteId,
      etape: etape ?? this.etape,
      octets: octets ?? this.octets,
      priseLe: priseLe ?? this.priseLe,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (visiteId.present) {
      map['visite_id'] = Variable<String>(visiteId.value);
    }
    if (etape.present) {
      map['etape'] = Variable<String>(etape.value);
    }
    if (octets.present) {
      map['octets'] = Variable<Uint8List>(octets.value);
    }
    if (priseLe.present) {
      map['prise_le'] = Variable<DateTime>(priseLe.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PhotosVisiteCompanion(')
          ..write('id: $id, ')
          ..write('visiteId: $visiteId, ')
          ..write('etape: $etape, ')
          ..write('octets: $octets, ')
          ..write('priseLe: $priseLe')
          ..write(')'))
        .toString();
  }
}

class $EnvoisEnAttenteTable extends EnvoisEnAttente
    with TableInfo<$EnvoisEnAttenteTable, EnvoiLocal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EnvoisEnAttenteTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _utilisateurIdMeta = const VerificationMeta(
    'utilisateurId',
  );
  @override
  late final GeneratedColumn<String> utilisateurId = GeneratedColumn<String>(
    'utilisateur_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cleMeta = const VerificationMeta('cle');
  @override
  late final GeneratedColumn<String> cle = GeneratedColumn<String>(
    'cle',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _refLocaleMeta = const VerificationMeta(
    'refLocale',
  );
  @override
  late final GeneratedColumn<String> refLocale = GeneratedColumn<String>(
    'ref_locale',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serveurIdMeta = const VerificationMeta(
    'serveurId',
  );
  @override
  late final GeneratedColumn<String> serveurId = GeneratedColumn<String>(
    'serveur_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _etatMeta = const VerificationMeta('etat');
  @override
  late final GeneratedColumn<String> etat = GeneratedColumn<String>(
    'etat',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('a_envoyer'),
  );
  static const VerificationMeta _essaisMeta = const VerificationMeta('essais');
  @override
  late final GeneratedColumn<int> essais = GeneratedColumn<int>(
    'essais',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _derniereErreurMeta = const VerificationMeta(
    'derniereErreur',
  );
  @override
  late final GeneratedColumn<String> derniereErreur = GeneratedColumn<String>(
    'derniere_erreur',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _creeLeMeta = const VerificationMeta('creeLe');
  @override
  late final GeneratedColumn<DateTime> creeLe = GeneratedColumn<DateTime>(
    'cree_le',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _misAJourLeMeta = const VerificationMeta(
    'misAJourLe',
  );
  @override
  late final GeneratedColumn<DateTime> misAJourLe = GeneratedColumn<DateTime>(
    'mis_a_jour_le',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _envoyeLeMeta = const VerificationMeta(
    'envoyeLe',
  );
  @override
  late final GeneratedColumn<DateTime> envoyeLe = GeneratedColumn<DateTime>(
    'envoye_le',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    utilisateurId,
    type,
    cle,
    payload,
    refLocale,
    serveurId,
    etat,
    essais,
    derniereErreur,
    creeLe,
    misAJourLe,
    envoyeLe,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'envois_en_attente';
  @override
  VerificationContext validateIntegrity(
    Insertable<EnvoiLocal> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('utilisateur_id')) {
      context.handle(
        _utilisateurIdMeta,
        utilisateurId.isAcceptableOrUnknown(
          data['utilisateur_id']!,
          _utilisateurIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_utilisateurIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('cle')) {
      context.handle(
        _cleMeta,
        cle.isAcceptableOrUnknown(data['cle']!, _cleMeta),
      );
    } else if (isInserting) {
      context.missing(_cleMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('ref_locale')) {
      context.handle(
        _refLocaleMeta,
        refLocale.isAcceptableOrUnknown(data['ref_locale']!, _refLocaleMeta),
      );
    }
    if (data.containsKey('serveur_id')) {
      context.handle(
        _serveurIdMeta,
        serveurId.isAcceptableOrUnknown(data['serveur_id']!, _serveurIdMeta),
      );
    }
    if (data.containsKey('etat')) {
      context.handle(
        _etatMeta,
        etat.isAcceptableOrUnknown(data['etat']!, _etatMeta),
      );
    }
    if (data.containsKey('essais')) {
      context.handle(
        _essaisMeta,
        essais.isAcceptableOrUnknown(data['essais']!, _essaisMeta),
      );
    }
    if (data.containsKey('derniere_erreur')) {
      context.handle(
        _derniereErreurMeta,
        derniereErreur.isAcceptableOrUnknown(
          data['derniere_erreur']!,
          _derniereErreurMeta,
        ),
      );
    }
    if (data.containsKey('cree_le')) {
      context.handle(
        _creeLeMeta,
        creeLe.isAcceptableOrUnknown(data['cree_le']!, _creeLeMeta),
      );
    }
    if (data.containsKey('mis_a_jour_le')) {
      context.handle(
        _misAJourLeMeta,
        misAJourLe.isAcceptableOrUnknown(
          data['mis_a_jour_le']!,
          _misAJourLeMeta,
        ),
      );
    }
    if (data.containsKey('envoye_le')) {
      context.handle(
        _envoyeLeMeta,
        envoyeLe.isAcceptableOrUnknown(data['envoye_le']!, _envoyeLeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EnvoiLocal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EnvoiLocal(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      utilisateurId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}utilisateur_id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      cle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cle'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      refLocale: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ref_locale'],
      ),
      serveurId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}serveur_id'],
      ),
      etat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etat'],
      )!,
      essais: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}essais'],
      )!,
      derniereErreur: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}derniere_erreur'],
      ),
      creeLe: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}cree_le'],
      )!,
      misAJourLe: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}mis_a_jour_le'],
      )!,
      envoyeLe: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}envoye_le'],
      ),
    );
  }

  @override
  $EnvoisEnAttenteTable createAlias(String alias) {
    return $EnvoisEnAttenteTable(attachedDatabase, alias);
  }
}

class EnvoiLocal extends DataClass implements Insertable<EnvoiLocal> {
  /// Ordre d'arrivée : la file se vide du plus ancien au plus récent.
  final int id;

  /// Utilisateur qui a validé l'élément : la file d'un autre compte n'est pas envoyée avec le jeton de celui-ci.
  final String utilisateurId;

  /// `visite` ou `commande`.
  final String type;

  /// Clé d'idempotence stable : `idApk` de la visite, `idCommandeApk` de la commande.
  final String cle;

  /// Corps JSON de l'appel de création (voir `corps_visite.dart` et `corps_commande.dart`).
  final String payload;

  /// Identifiant de la visite dans l'app, pour la repasser en « Envoyée » une fois partie.
  final String? refLocale;

  /// Identifiant donné par le CRM une fois la visite ou la commande créée : les photos et la validation s'y rattachent.
  final String? serveurId;

  /// `a_envoyer`, `en_cours`, `envoye` ou `erreur`.
  final String etat;
  final int essais;
  final String? derniereErreur;
  final DateTime creeLe;
  final DateTime misAJourLe;
  final DateTime? envoyeLe;
  const EnvoiLocal({
    required this.id,
    required this.utilisateurId,
    required this.type,
    required this.cle,
    required this.payload,
    this.refLocale,
    this.serveurId,
    required this.etat,
    required this.essais,
    this.derniereErreur,
    required this.creeLe,
    required this.misAJourLe,
    this.envoyeLe,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['utilisateur_id'] = Variable<String>(utilisateurId);
    map['type'] = Variable<String>(type);
    map['cle'] = Variable<String>(cle);
    map['payload'] = Variable<String>(payload);
    if (!nullToAbsent || refLocale != null) {
      map['ref_locale'] = Variable<String>(refLocale);
    }
    if (!nullToAbsent || serveurId != null) {
      map['serveur_id'] = Variable<String>(serveurId);
    }
    map['etat'] = Variable<String>(etat);
    map['essais'] = Variable<int>(essais);
    if (!nullToAbsent || derniereErreur != null) {
      map['derniere_erreur'] = Variable<String>(derniereErreur);
    }
    map['cree_le'] = Variable<DateTime>(creeLe);
    map['mis_a_jour_le'] = Variable<DateTime>(misAJourLe);
    if (!nullToAbsent || envoyeLe != null) {
      map['envoye_le'] = Variable<DateTime>(envoyeLe);
    }
    return map;
  }

  EnvoisEnAttenteCompanion toCompanion(bool nullToAbsent) {
    return EnvoisEnAttenteCompanion(
      id: Value(id),
      utilisateurId: Value(utilisateurId),
      type: Value(type),
      cle: Value(cle),
      payload: Value(payload),
      refLocale: refLocale == null && nullToAbsent
          ? const Value.absent()
          : Value(refLocale),
      serveurId: serveurId == null && nullToAbsent
          ? const Value.absent()
          : Value(serveurId),
      etat: Value(etat),
      essais: Value(essais),
      derniereErreur: derniereErreur == null && nullToAbsent
          ? const Value.absent()
          : Value(derniereErreur),
      creeLe: Value(creeLe),
      misAJourLe: Value(misAJourLe),
      envoyeLe: envoyeLe == null && nullToAbsent
          ? const Value.absent()
          : Value(envoyeLe),
    );
  }

  factory EnvoiLocal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EnvoiLocal(
      id: serializer.fromJson<int>(json['id']),
      utilisateurId: serializer.fromJson<String>(json['utilisateurId']),
      type: serializer.fromJson<String>(json['type']),
      cle: serializer.fromJson<String>(json['cle']),
      payload: serializer.fromJson<String>(json['payload']),
      refLocale: serializer.fromJson<String?>(json['refLocale']),
      serveurId: serializer.fromJson<String?>(json['serveurId']),
      etat: serializer.fromJson<String>(json['etat']),
      essais: serializer.fromJson<int>(json['essais']),
      derniereErreur: serializer.fromJson<String?>(json['derniereErreur']),
      creeLe: serializer.fromJson<DateTime>(json['creeLe']),
      misAJourLe: serializer.fromJson<DateTime>(json['misAJourLe']),
      envoyeLe: serializer.fromJson<DateTime?>(json['envoyeLe']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'utilisateurId': serializer.toJson<String>(utilisateurId),
      'type': serializer.toJson<String>(type),
      'cle': serializer.toJson<String>(cle),
      'payload': serializer.toJson<String>(payload),
      'refLocale': serializer.toJson<String?>(refLocale),
      'serveurId': serializer.toJson<String?>(serveurId),
      'etat': serializer.toJson<String>(etat),
      'essais': serializer.toJson<int>(essais),
      'derniereErreur': serializer.toJson<String?>(derniereErreur),
      'creeLe': serializer.toJson<DateTime>(creeLe),
      'misAJourLe': serializer.toJson<DateTime>(misAJourLe),
      'envoyeLe': serializer.toJson<DateTime?>(envoyeLe),
    };
  }

  EnvoiLocal copyWith({
    int? id,
    String? utilisateurId,
    String? type,
    String? cle,
    String? payload,
    Value<String?> refLocale = const Value.absent(),
    Value<String?> serveurId = const Value.absent(),
    String? etat,
    int? essais,
    Value<String?> derniereErreur = const Value.absent(),
    DateTime? creeLe,
    DateTime? misAJourLe,
    Value<DateTime?> envoyeLe = const Value.absent(),
  }) => EnvoiLocal(
    id: id ?? this.id,
    utilisateurId: utilisateurId ?? this.utilisateurId,
    type: type ?? this.type,
    cle: cle ?? this.cle,
    payload: payload ?? this.payload,
    refLocale: refLocale.present ? refLocale.value : this.refLocale,
    serveurId: serveurId.present ? serveurId.value : this.serveurId,
    etat: etat ?? this.etat,
    essais: essais ?? this.essais,
    derniereErreur: derniereErreur.present
        ? derniereErreur.value
        : this.derniereErreur,
    creeLe: creeLe ?? this.creeLe,
    misAJourLe: misAJourLe ?? this.misAJourLe,
    envoyeLe: envoyeLe.present ? envoyeLe.value : this.envoyeLe,
  );
  EnvoiLocal copyWithCompanion(EnvoisEnAttenteCompanion data) {
    return EnvoiLocal(
      id: data.id.present ? data.id.value : this.id,
      utilisateurId: data.utilisateurId.present
          ? data.utilisateurId.value
          : this.utilisateurId,
      type: data.type.present ? data.type.value : this.type,
      cle: data.cle.present ? data.cle.value : this.cle,
      payload: data.payload.present ? data.payload.value : this.payload,
      refLocale: data.refLocale.present ? data.refLocale.value : this.refLocale,
      serveurId: data.serveurId.present ? data.serveurId.value : this.serveurId,
      etat: data.etat.present ? data.etat.value : this.etat,
      essais: data.essais.present ? data.essais.value : this.essais,
      derniereErreur: data.derniereErreur.present
          ? data.derniereErreur.value
          : this.derniereErreur,
      creeLe: data.creeLe.present ? data.creeLe.value : this.creeLe,
      misAJourLe: data.misAJourLe.present
          ? data.misAJourLe.value
          : this.misAJourLe,
      envoyeLe: data.envoyeLe.present ? data.envoyeLe.value : this.envoyeLe,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EnvoiLocal(')
          ..write('id: $id, ')
          ..write('utilisateurId: $utilisateurId, ')
          ..write('type: $type, ')
          ..write('cle: $cle, ')
          ..write('payload: $payload, ')
          ..write('refLocale: $refLocale, ')
          ..write('serveurId: $serveurId, ')
          ..write('etat: $etat, ')
          ..write('essais: $essais, ')
          ..write('derniereErreur: $derniereErreur, ')
          ..write('creeLe: $creeLe, ')
          ..write('misAJourLe: $misAJourLe, ')
          ..write('envoyeLe: $envoyeLe')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    utilisateurId,
    type,
    cle,
    payload,
    refLocale,
    serveurId,
    etat,
    essais,
    derniereErreur,
    creeLe,
    misAJourLe,
    envoyeLe,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EnvoiLocal &&
          other.id == this.id &&
          other.utilisateurId == this.utilisateurId &&
          other.type == this.type &&
          other.cle == this.cle &&
          other.payload == this.payload &&
          other.refLocale == this.refLocale &&
          other.serveurId == this.serveurId &&
          other.etat == this.etat &&
          other.essais == this.essais &&
          other.derniereErreur == this.derniereErreur &&
          other.creeLe == this.creeLe &&
          other.misAJourLe == this.misAJourLe &&
          other.envoyeLe == this.envoyeLe);
}

class EnvoisEnAttenteCompanion extends UpdateCompanion<EnvoiLocal> {
  final Value<int> id;
  final Value<String> utilisateurId;
  final Value<String> type;
  final Value<String> cle;
  final Value<String> payload;
  final Value<String?> refLocale;
  final Value<String?> serveurId;
  final Value<String> etat;
  final Value<int> essais;
  final Value<String?> derniereErreur;
  final Value<DateTime> creeLe;
  final Value<DateTime> misAJourLe;
  final Value<DateTime?> envoyeLe;
  const EnvoisEnAttenteCompanion({
    this.id = const Value.absent(),
    this.utilisateurId = const Value.absent(),
    this.type = const Value.absent(),
    this.cle = const Value.absent(),
    this.payload = const Value.absent(),
    this.refLocale = const Value.absent(),
    this.serveurId = const Value.absent(),
    this.etat = const Value.absent(),
    this.essais = const Value.absent(),
    this.derniereErreur = const Value.absent(),
    this.creeLe = const Value.absent(),
    this.misAJourLe = const Value.absent(),
    this.envoyeLe = const Value.absent(),
  });
  EnvoisEnAttenteCompanion.insert({
    this.id = const Value.absent(),
    required String utilisateurId,
    required String type,
    required String cle,
    required String payload,
    this.refLocale = const Value.absent(),
    this.serveurId = const Value.absent(),
    this.etat = const Value.absent(),
    this.essais = const Value.absent(),
    this.derniereErreur = const Value.absent(),
    this.creeLe = const Value.absent(),
    this.misAJourLe = const Value.absent(),
    this.envoyeLe = const Value.absent(),
  }) : utilisateurId = Value(utilisateurId),
       type = Value(type),
       cle = Value(cle),
       payload = Value(payload);
  static Insertable<EnvoiLocal> custom({
    Expression<int>? id,
    Expression<String>? utilisateurId,
    Expression<String>? type,
    Expression<String>? cle,
    Expression<String>? payload,
    Expression<String>? refLocale,
    Expression<String>? serveurId,
    Expression<String>? etat,
    Expression<int>? essais,
    Expression<String>? derniereErreur,
    Expression<DateTime>? creeLe,
    Expression<DateTime>? misAJourLe,
    Expression<DateTime>? envoyeLe,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (utilisateurId != null) 'utilisateur_id': utilisateurId,
      if (type != null) 'type': type,
      if (cle != null) 'cle': cle,
      if (payload != null) 'payload': payload,
      if (refLocale != null) 'ref_locale': refLocale,
      if (serveurId != null) 'serveur_id': serveurId,
      if (etat != null) 'etat': etat,
      if (essais != null) 'essais': essais,
      if (derniereErreur != null) 'derniere_erreur': derniereErreur,
      if (creeLe != null) 'cree_le': creeLe,
      if (misAJourLe != null) 'mis_a_jour_le': misAJourLe,
      if (envoyeLe != null) 'envoye_le': envoyeLe,
    });
  }

  EnvoisEnAttenteCompanion copyWith({
    Value<int>? id,
    Value<String>? utilisateurId,
    Value<String>? type,
    Value<String>? cle,
    Value<String>? payload,
    Value<String?>? refLocale,
    Value<String?>? serveurId,
    Value<String>? etat,
    Value<int>? essais,
    Value<String?>? derniereErreur,
    Value<DateTime>? creeLe,
    Value<DateTime>? misAJourLe,
    Value<DateTime?>? envoyeLe,
  }) {
    return EnvoisEnAttenteCompanion(
      id: id ?? this.id,
      utilisateurId: utilisateurId ?? this.utilisateurId,
      type: type ?? this.type,
      cle: cle ?? this.cle,
      payload: payload ?? this.payload,
      refLocale: refLocale ?? this.refLocale,
      serveurId: serveurId ?? this.serveurId,
      etat: etat ?? this.etat,
      essais: essais ?? this.essais,
      derniereErreur: derniereErreur ?? this.derniereErreur,
      creeLe: creeLe ?? this.creeLe,
      misAJourLe: misAJourLe ?? this.misAJourLe,
      envoyeLe: envoyeLe ?? this.envoyeLe,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (utilisateurId.present) {
      map['utilisateur_id'] = Variable<String>(utilisateurId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (cle.present) {
      map['cle'] = Variable<String>(cle.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (refLocale.present) {
      map['ref_locale'] = Variable<String>(refLocale.value);
    }
    if (serveurId.present) {
      map['serveur_id'] = Variable<String>(serveurId.value);
    }
    if (etat.present) {
      map['etat'] = Variable<String>(etat.value);
    }
    if (essais.present) {
      map['essais'] = Variable<int>(essais.value);
    }
    if (derniereErreur.present) {
      map['derniere_erreur'] = Variable<String>(derniereErreur.value);
    }
    if (creeLe.present) {
      map['cree_le'] = Variable<DateTime>(creeLe.value);
    }
    if (misAJourLe.present) {
      map['mis_a_jour_le'] = Variable<DateTime>(misAJourLe.value);
    }
    if (envoyeLe.present) {
      map['envoye_le'] = Variable<DateTime>(envoyeLe.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EnvoisEnAttenteCompanion(')
          ..write('id: $id, ')
          ..write('utilisateurId: $utilisateurId, ')
          ..write('type: $type, ')
          ..write('cle: $cle, ')
          ..write('payload: $payload, ')
          ..write('refLocale: $refLocale, ')
          ..write('serveurId: $serveurId, ')
          ..write('etat: $etat, ')
          ..write('essais: $essais, ')
          ..write('derniereErreur: $derniereErreur, ')
          ..write('creeLe: $creeLe, ')
          ..write('misAJourLe: $misAJourLe, ')
          ..write('envoyeLe: $envoyeLe')
          ..write(')'))
        .toString();
  }
}

class $EnvoisFichiersTable extends EnvoisFichiers
    with TableInfo<$EnvoisFichiersTable, EnvoiFichierLocal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EnvoisFichiersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _envoiIdMeta = const VerificationMeta(
    'envoiId',
  );
  @override
  late final GeneratedColumn<int> envoiId = GeneratedColumn<int>(
    'envoi_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _photoIdMeta = const VerificationMeta(
    'photoId',
  );
  @override
  late final GeneratedColumn<int> photoId = GeneratedColumn<int>(
    'photo_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _etapeMeta = const VerificationMeta('etape');
  @override
  late final GeneratedColumn<String> etape = GeneratedColumn<String>(
    'etape',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idApkMeta = const VerificationMeta('idApk');
  @override
  late final GeneratedColumn<String> idApk = GeneratedColumn<String>(
    'id_apk',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _etatMeta = const VerificationMeta('etat');
  @override
  late final GeneratedColumn<String> etat = GeneratedColumn<String>(
    'etat',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('a_envoyer'),
  );
  static const VerificationMeta _derniereErreurMeta = const VerificationMeta(
    'derniereErreur',
  );
  @override
  late final GeneratedColumn<String> derniereErreur = GeneratedColumn<String>(
    'derniere_erreur',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    envoiId,
    photoId,
    etape,
    idApk,
    etat,
    derniereErreur,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'envois_fichiers';
  @override
  VerificationContext validateIntegrity(
    Insertable<EnvoiFichierLocal> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('envoi_id')) {
      context.handle(
        _envoiIdMeta,
        envoiId.isAcceptableOrUnknown(data['envoi_id']!, _envoiIdMeta),
      );
    } else if (isInserting) {
      context.missing(_envoiIdMeta);
    }
    if (data.containsKey('photo_id')) {
      context.handle(
        _photoIdMeta,
        photoId.isAcceptableOrUnknown(data['photo_id']!, _photoIdMeta),
      );
    }
    if (data.containsKey('etape')) {
      context.handle(
        _etapeMeta,
        etape.isAcceptableOrUnknown(data['etape']!, _etapeMeta),
      );
    } else if (isInserting) {
      context.missing(_etapeMeta);
    }
    if (data.containsKey('id_apk')) {
      context.handle(
        _idApkMeta,
        idApk.isAcceptableOrUnknown(data['id_apk']!, _idApkMeta),
      );
    } else if (isInserting) {
      context.missing(_idApkMeta);
    }
    if (data.containsKey('etat')) {
      context.handle(
        _etatMeta,
        etat.isAcceptableOrUnknown(data['etat']!, _etatMeta),
      );
    }
    if (data.containsKey('derniere_erreur')) {
      context.handle(
        _derniereErreurMeta,
        derniereErreur.isAcceptableOrUnknown(
          data['derniere_erreur']!,
          _derniereErreurMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EnvoiFichierLocal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EnvoiFichierLocal(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      envoiId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}envoi_id'],
      )!,
      photoId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}photo_id'],
      ),
      etape: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etape'],
      )!,
      idApk: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id_apk'],
      )!,
      etat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etat'],
      )!,
      derniereErreur: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}derniere_erreur'],
      ),
    );
  }

  @override
  $EnvoisFichiersTable createAlias(String alias) {
    return $EnvoisFichiersTable(attachedDatabase, alias);
  }
}

class EnvoiFichierLocal extends DataClass
    implements Insertable<EnvoiFichierLocal> {
  final int id;
  final int envoiId;

  /// Ligne de [PhotosVisite] (nulle une fois la photo acceptée et ses octets effacés).
  final int? photoId;

  /// Étape du parcours (`arrivee`, `rayonArrivee`, `rayonFin`).
  final String etape;

  /// Clé d'idempotence de la photo côté CRM : un renvoi ne crée pas de doublon.
  final String idApk;

  /// `a_envoyer`, `envoye` ou `refuse`.
  final String etat;
  final String? derniereErreur;
  const EnvoiFichierLocal({
    required this.id,
    required this.envoiId,
    this.photoId,
    required this.etape,
    required this.idApk,
    required this.etat,
    this.derniereErreur,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['envoi_id'] = Variable<int>(envoiId);
    if (!nullToAbsent || photoId != null) {
      map['photo_id'] = Variable<int>(photoId);
    }
    map['etape'] = Variable<String>(etape);
    map['id_apk'] = Variable<String>(idApk);
    map['etat'] = Variable<String>(etat);
    if (!nullToAbsent || derniereErreur != null) {
      map['derniere_erreur'] = Variable<String>(derniereErreur);
    }
    return map;
  }

  EnvoisFichiersCompanion toCompanion(bool nullToAbsent) {
    return EnvoisFichiersCompanion(
      id: Value(id),
      envoiId: Value(envoiId),
      photoId: photoId == null && nullToAbsent
          ? const Value.absent()
          : Value(photoId),
      etape: Value(etape),
      idApk: Value(idApk),
      etat: Value(etat),
      derniereErreur: derniereErreur == null && nullToAbsent
          ? const Value.absent()
          : Value(derniereErreur),
    );
  }

  factory EnvoiFichierLocal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EnvoiFichierLocal(
      id: serializer.fromJson<int>(json['id']),
      envoiId: serializer.fromJson<int>(json['envoiId']),
      photoId: serializer.fromJson<int?>(json['photoId']),
      etape: serializer.fromJson<String>(json['etape']),
      idApk: serializer.fromJson<String>(json['idApk']),
      etat: serializer.fromJson<String>(json['etat']),
      derniereErreur: serializer.fromJson<String?>(json['derniereErreur']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'envoiId': serializer.toJson<int>(envoiId),
      'photoId': serializer.toJson<int?>(photoId),
      'etape': serializer.toJson<String>(etape),
      'idApk': serializer.toJson<String>(idApk),
      'etat': serializer.toJson<String>(etat),
      'derniereErreur': serializer.toJson<String?>(derniereErreur),
    };
  }

  EnvoiFichierLocal copyWith({
    int? id,
    int? envoiId,
    Value<int?> photoId = const Value.absent(),
    String? etape,
    String? idApk,
    String? etat,
    Value<String?> derniereErreur = const Value.absent(),
  }) => EnvoiFichierLocal(
    id: id ?? this.id,
    envoiId: envoiId ?? this.envoiId,
    photoId: photoId.present ? photoId.value : this.photoId,
    etape: etape ?? this.etape,
    idApk: idApk ?? this.idApk,
    etat: etat ?? this.etat,
    derniereErreur: derniereErreur.present
        ? derniereErreur.value
        : this.derniereErreur,
  );
  EnvoiFichierLocal copyWithCompanion(EnvoisFichiersCompanion data) {
    return EnvoiFichierLocal(
      id: data.id.present ? data.id.value : this.id,
      envoiId: data.envoiId.present ? data.envoiId.value : this.envoiId,
      photoId: data.photoId.present ? data.photoId.value : this.photoId,
      etape: data.etape.present ? data.etape.value : this.etape,
      idApk: data.idApk.present ? data.idApk.value : this.idApk,
      etat: data.etat.present ? data.etat.value : this.etat,
      derniereErreur: data.derniereErreur.present
          ? data.derniereErreur.value
          : this.derniereErreur,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EnvoiFichierLocal(')
          ..write('id: $id, ')
          ..write('envoiId: $envoiId, ')
          ..write('photoId: $photoId, ')
          ..write('etape: $etape, ')
          ..write('idApk: $idApk, ')
          ..write('etat: $etat, ')
          ..write('derniereErreur: $derniereErreur')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, envoiId, photoId, etape, idApk, etat, derniereErreur);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EnvoiFichierLocal &&
          other.id == this.id &&
          other.envoiId == this.envoiId &&
          other.photoId == this.photoId &&
          other.etape == this.etape &&
          other.idApk == this.idApk &&
          other.etat == this.etat &&
          other.derniereErreur == this.derniereErreur);
}

class EnvoisFichiersCompanion extends UpdateCompanion<EnvoiFichierLocal> {
  final Value<int> id;
  final Value<int> envoiId;
  final Value<int?> photoId;
  final Value<String> etape;
  final Value<String> idApk;
  final Value<String> etat;
  final Value<String?> derniereErreur;
  const EnvoisFichiersCompanion({
    this.id = const Value.absent(),
    this.envoiId = const Value.absent(),
    this.photoId = const Value.absent(),
    this.etape = const Value.absent(),
    this.idApk = const Value.absent(),
    this.etat = const Value.absent(),
    this.derniereErreur = const Value.absent(),
  });
  EnvoisFichiersCompanion.insert({
    this.id = const Value.absent(),
    required int envoiId,
    this.photoId = const Value.absent(),
    required String etape,
    required String idApk,
    this.etat = const Value.absent(),
    this.derniereErreur = const Value.absent(),
  }) : envoiId = Value(envoiId),
       etape = Value(etape),
       idApk = Value(idApk);
  static Insertable<EnvoiFichierLocal> custom({
    Expression<int>? id,
    Expression<int>? envoiId,
    Expression<int>? photoId,
    Expression<String>? etape,
    Expression<String>? idApk,
    Expression<String>? etat,
    Expression<String>? derniereErreur,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (envoiId != null) 'envoi_id': envoiId,
      if (photoId != null) 'photo_id': photoId,
      if (etape != null) 'etape': etape,
      if (idApk != null) 'id_apk': idApk,
      if (etat != null) 'etat': etat,
      if (derniereErreur != null) 'derniere_erreur': derniereErreur,
    });
  }

  EnvoisFichiersCompanion copyWith({
    Value<int>? id,
    Value<int>? envoiId,
    Value<int?>? photoId,
    Value<String>? etape,
    Value<String>? idApk,
    Value<String>? etat,
    Value<String?>? derniereErreur,
  }) {
    return EnvoisFichiersCompanion(
      id: id ?? this.id,
      envoiId: envoiId ?? this.envoiId,
      photoId: photoId ?? this.photoId,
      etape: etape ?? this.etape,
      idApk: idApk ?? this.idApk,
      etat: etat ?? this.etat,
      derniereErreur: derniereErreur ?? this.derniereErreur,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (envoiId.present) {
      map['envoi_id'] = Variable<int>(envoiId.value);
    }
    if (photoId.present) {
      map['photo_id'] = Variable<int>(photoId.value);
    }
    if (etape.present) {
      map['etape'] = Variable<String>(etape.value);
    }
    if (idApk.present) {
      map['id_apk'] = Variable<String>(idApk.value);
    }
    if (etat.present) {
      map['etat'] = Variable<String>(etat.value);
    }
    if (derniereErreur.present) {
      map['derniere_erreur'] = Variable<String>(derniereErreur.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EnvoisFichiersCompanion(')
          ..write('id: $id, ')
          ..write('envoiId: $envoiId, ')
          ..write('photoId: $photoId, ')
          ..write('etape: $etape, ')
          ..write('idApk: $idApk, ')
          ..write('etat: $etat, ')
          ..write('derniereErreur: $derniereErreur')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $MetaBaseTable metaBase = $MetaBaseTable(this);
  late final $ArticlesLocauxTable articlesLocaux = $ArticlesLocauxTable(this);
  late final $ClientsLocauxTable clientsLocaux = $ClientsLocauxTable(this);
  late final $EnregistrementsLocauxTable enregistrementsLocaux =
      $EnregistrementsLocauxTable(this);
  late final $PhotosLocalesTable photosLocales = $PhotosLocalesTable(this);
  late final $PhotosVisiteTable photosVisite = $PhotosVisiteTable(this);
  late final $EnvoisEnAttenteTable envoisEnAttente = $EnvoisEnAttenteTable(
    this,
  );
  late final $EnvoisFichiersTable envoisFichiers = $EnvoisFichiersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    metaBase,
    articlesLocaux,
    clientsLocaux,
    enregistrementsLocaux,
    photosLocales,
    photosVisite,
    envoisEnAttente,
    envoisFichiers,
  ];
}

typedef $$MetaBaseTableCreateCompanionBuilder =
    MetaBaseCompanion Function({
      required String cle,
      required String valeur,
      Value<DateTime> misAJourLe,
      Value<int> rowid,
    });
typedef $$MetaBaseTableUpdateCompanionBuilder =
    MetaBaseCompanion Function({
      Value<String> cle,
      Value<String> valeur,
      Value<DateTime> misAJourLe,
      Value<int> rowid,
    });

class $$MetaBaseTableFilterComposer
    extends Composer<_$AppDatabase, $MetaBaseTable> {
  $$MetaBaseTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cle => $composableBuilder(
    column: $table.cle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get valeur => $composableBuilder(
    column: $table.valeur,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get misAJourLe => $composableBuilder(
    column: $table.misAJourLe,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MetaBaseTableOrderingComposer
    extends Composer<_$AppDatabase, $MetaBaseTable> {
  $$MetaBaseTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cle => $composableBuilder(
    column: $table.cle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get valeur => $composableBuilder(
    column: $table.valeur,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get misAJourLe => $composableBuilder(
    column: $table.misAJourLe,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MetaBaseTableAnnotationComposer
    extends Composer<_$AppDatabase, $MetaBaseTable> {
  $$MetaBaseTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cle =>
      $composableBuilder(column: $table.cle, builder: (column) => column);

  GeneratedColumn<String> get valeur =>
      $composableBuilder(column: $table.valeur, builder: (column) => column);

  GeneratedColumn<DateTime> get misAJourLe => $composableBuilder(
    column: $table.misAJourLe,
    builder: (column) => column,
  );
}

class $$MetaBaseTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MetaBaseTable,
          MetaBaseData,
          $$MetaBaseTableFilterComposer,
          $$MetaBaseTableOrderingComposer,
          $$MetaBaseTableAnnotationComposer,
          $$MetaBaseTableCreateCompanionBuilder,
          $$MetaBaseTableUpdateCompanionBuilder,
          (
            MetaBaseData,
            BaseReferences<_$AppDatabase, $MetaBaseTable, MetaBaseData>,
          ),
          MetaBaseData,
          PrefetchHooks Function()
        > {
  $$MetaBaseTableTableManager(_$AppDatabase db, $MetaBaseTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MetaBaseTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MetaBaseTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MetaBaseTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> cle = const Value.absent(),
                Value<String> valeur = const Value.absent(),
                Value<DateTime> misAJourLe = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MetaBaseCompanion(
                cle: cle,
                valeur: valeur,
                misAJourLe: misAJourLe,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String cle,
                required String valeur,
                Value<DateTime> misAJourLe = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MetaBaseCompanion.insert(
                cle: cle,
                valeur: valeur,
                misAJourLe: misAJourLe,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MetaBaseTable, MetaBaseData>(table),
                  BaseReferences<_$AppDatabase, $MetaBaseTable, MetaBaseData>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MetaBaseTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MetaBaseTable,
      MetaBaseData,
      $$MetaBaseTableFilterComposer,
      $$MetaBaseTableOrderingComposer,
      $$MetaBaseTableAnnotationComposer,
      $$MetaBaseTableCreateCompanionBuilder,
      $$MetaBaseTableUpdateCompanionBuilder,
      (
        MetaBaseData,
        BaseReferences<_$AppDatabase, $MetaBaseTable, MetaBaseData>,
      ),
      MetaBaseData,
      PrefetchHooks Function()
    >;
typedef $$ArticlesLocauxTableCreateCompanionBuilder =
    ArticlesLocauxCompanion Function({
      required String id,
      required String codeAs400,
      required String libelle,
      Value<String?> gencode,
      Value<String?> marque,
      Value<String?> famille,
      Value<String?> gamme,
      Value<String?> typeArticle,
      Value<String?> statut,
      Value<int?> pcb,
      Value<int> stock,
      Value<bool> actif,
      Value<double?> prix,
      Value<bool> enPromo,
      Value<String?> promoLibelle,
      Value<bool> misEnAvant,
      Value<int> rowid,
    });
typedef $$ArticlesLocauxTableUpdateCompanionBuilder =
    ArticlesLocauxCompanion Function({
      Value<String> id,
      Value<String> codeAs400,
      Value<String> libelle,
      Value<String?> gencode,
      Value<String?> marque,
      Value<String?> famille,
      Value<String?> gamme,
      Value<String?> typeArticle,
      Value<String?> statut,
      Value<int?> pcb,
      Value<int> stock,
      Value<bool> actif,
      Value<double?> prix,
      Value<bool> enPromo,
      Value<String?> promoLibelle,
      Value<bool> misEnAvant,
      Value<int> rowid,
    });

class $$ArticlesLocauxTableFilterComposer
    extends Composer<_$AppDatabase, $ArticlesLocauxTable> {
  $$ArticlesLocauxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get codeAs400 => $composableBuilder(
    column: $table.codeAs400,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get libelle => $composableBuilder(
    column: $table.libelle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gencode => $composableBuilder(
    column: $table.gencode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get marque => $composableBuilder(
    column: $table.marque,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get famille => $composableBuilder(
    column: $table.famille,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gamme => $composableBuilder(
    column: $table.gamme,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get typeArticle => $composableBuilder(
    column: $table.typeArticle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get statut => $composableBuilder(
    column: $table.statut,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pcb => $composableBuilder(
    column: $table.pcb,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stock => $composableBuilder(
    column: $table.stock,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get actif => $composableBuilder(
    column: $table.actif,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get prix => $composableBuilder(
    column: $table.prix,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enPromo => $composableBuilder(
    column: $table.enPromo,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get promoLibelle => $composableBuilder(
    column: $table.promoLibelle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get misEnAvant => $composableBuilder(
    column: $table.misEnAvant,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ArticlesLocauxTableOrderingComposer
    extends Composer<_$AppDatabase, $ArticlesLocauxTable> {
  $$ArticlesLocauxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get codeAs400 => $composableBuilder(
    column: $table.codeAs400,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get libelle => $composableBuilder(
    column: $table.libelle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gencode => $composableBuilder(
    column: $table.gencode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get marque => $composableBuilder(
    column: $table.marque,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get famille => $composableBuilder(
    column: $table.famille,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gamme => $composableBuilder(
    column: $table.gamme,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get typeArticle => $composableBuilder(
    column: $table.typeArticle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get statut => $composableBuilder(
    column: $table.statut,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pcb => $composableBuilder(
    column: $table.pcb,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stock => $composableBuilder(
    column: $table.stock,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get actif => $composableBuilder(
    column: $table.actif,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get prix => $composableBuilder(
    column: $table.prix,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enPromo => $composableBuilder(
    column: $table.enPromo,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get promoLibelle => $composableBuilder(
    column: $table.promoLibelle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get misEnAvant => $composableBuilder(
    column: $table.misEnAvant,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ArticlesLocauxTableAnnotationComposer
    extends Composer<_$AppDatabase, $ArticlesLocauxTable> {
  $$ArticlesLocauxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get codeAs400 =>
      $composableBuilder(column: $table.codeAs400, builder: (column) => column);

  GeneratedColumn<String> get libelle =>
      $composableBuilder(column: $table.libelle, builder: (column) => column);

  GeneratedColumn<String> get gencode =>
      $composableBuilder(column: $table.gencode, builder: (column) => column);

  GeneratedColumn<String> get marque =>
      $composableBuilder(column: $table.marque, builder: (column) => column);

  GeneratedColumn<String> get famille =>
      $composableBuilder(column: $table.famille, builder: (column) => column);

  GeneratedColumn<String> get gamme =>
      $composableBuilder(column: $table.gamme, builder: (column) => column);

  GeneratedColumn<String> get typeArticle => $composableBuilder(
    column: $table.typeArticle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get statut =>
      $composableBuilder(column: $table.statut, builder: (column) => column);

  GeneratedColumn<int> get pcb =>
      $composableBuilder(column: $table.pcb, builder: (column) => column);

  GeneratedColumn<int> get stock =>
      $composableBuilder(column: $table.stock, builder: (column) => column);

  GeneratedColumn<bool> get actif =>
      $composableBuilder(column: $table.actif, builder: (column) => column);

  GeneratedColumn<double> get prix =>
      $composableBuilder(column: $table.prix, builder: (column) => column);

  GeneratedColumn<bool> get enPromo =>
      $composableBuilder(column: $table.enPromo, builder: (column) => column);

  GeneratedColumn<String> get promoLibelle => $composableBuilder(
    column: $table.promoLibelle,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get misEnAvant => $composableBuilder(
    column: $table.misEnAvant,
    builder: (column) => column,
  );
}

class $$ArticlesLocauxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ArticlesLocauxTable,
          ArticleLocal,
          $$ArticlesLocauxTableFilterComposer,
          $$ArticlesLocauxTableOrderingComposer,
          $$ArticlesLocauxTableAnnotationComposer,
          $$ArticlesLocauxTableCreateCompanionBuilder,
          $$ArticlesLocauxTableUpdateCompanionBuilder,
          (
            ArticleLocal,
            BaseReferences<_$AppDatabase, $ArticlesLocauxTable, ArticleLocal>,
          ),
          ArticleLocal,
          PrefetchHooks Function()
        > {
  $$ArticlesLocauxTableTableManager(
    _$AppDatabase db,
    $ArticlesLocauxTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ArticlesLocauxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ArticlesLocauxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ArticlesLocauxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> codeAs400 = const Value.absent(),
                Value<String> libelle = const Value.absent(),
                Value<String?> gencode = const Value.absent(),
                Value<String?> marque = const Value.absent(),
                Value<String?> famille = const Value.absent(),
                Value<String?> gamme = const Value.absent(),
                Value<String?> typeArticle = const Value.absent(),
                Value<String?> statut = const Value.absent(),
                Value<int?> pcb = const Value.absent(),
                Value<int> stock = const Value.absent(),
                Value<bool> actif = const Value.absent(),
                Value<double?> prix = const Value.absent(),
                Value<bool> enPromo = const Value.absent(),
                Value<String?> promoLibelle = const Value.absent(),
                Value<bool> misEnAvant = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArticlesLocauxCompanion(
                id: id,
                codeAs400: codeAs400,
                libelle: libelle,
                gencode: gencode,
                marque: marque,
                famille: famille,
                gamme: gamme,
                typeArticle: typeArticle,
                statut: statut,
                pcb: pcb,
                stock: stock,
                actif: actif,
                prix: prix,
                enPromo: enPromo,
                promoLibelle: promoLibelle,
                misEnAvant: misEnAvant,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String codeAs400,
                required String libelle,
                Value<String?> gencode = const Value.absent(),
                Value<String?> marque = const Value.absent(),
                Value<String?> famille = const Value.absent(),
                Value<String?> gamme = const Value.absent(),
                Value<String?> typeArticle = const Value.absent(),
                Value<String?> statut = const Value.absent(),
                Value<int?> pcb = const Value.absent(),
                Value<int> stock = const Value.absent(),
                Value<bool> actif = const Value.absent(),
                Value<double?> prix = const Value.absent(),
                Value<bool> enPromo = const Value.absent(),
                Value<String?> promoLibelle = const Value.absent(),
                Value<bool> misEnAvant = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ArticlesLocauxCompanion.insert(
                id: id,
                codeAs400: codeAs400,
                libelle: libelle,
                gencode: gencode,
                marque: marque,
                famille: famille,
                gamme: gamme,
                typeArticle: typeArticle,
                statut: statut,
                pcb: pcb,
                stock: stock,
                actif: actif,
                prix: prix,
                enPromo: enPromo,
                promoLibelle: promoLibelle,
                misEnAvant: misEnAvant,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ArticlesLocauxTable, ArticleLocal>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ArticlesLocauxTable,
                    ArticleLocal
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ArticlesLocauxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ArticlesLocauxTable,
      ArticleLocal,
      $$ArticlesLocauxTableFilterComposer,
      $$ArticlesLocauxTableOrderingComposer,
      $$ArticlesLocauxTableAnnotationComposer,
      $$ArticlesLocauxTableCreateCompanionBuilder,
      $$ArticlesLocauxTableUpdateCompanionBuilder,
      (
        ArticleLocal,
        BaseReferences<_$AppDatabase, $ArticlesLocauxTable, ArticleLocal>,
      ),
      ArticleLocal,
      PrefetchHooks Function()
    >;
typedef $$ClientsLocauxTableCreateCompanionBuilder =
    ClientsLocauxCompanion Function({
      required String id,
      required String codeAs400,
      required String enseigne,
      required String raisonSociale,
      Value<String?> adresse1,
      Value<String?> codePostal,
      Value<String?> ville,
      Value<String?> telephone,
      Value<String?> contact,
      Value<bool> actif,
      Value<String?> niveauClass,
      Value<int> rowid,
    });
typedef $$ClientsLocauxTableUpdateCompanionBuilder =
    ClientsLocauxCompanion Function({
      Value<String> id,
      Value<String> codeAs400,
      Value<String> enseigne,
      Value<String> raisonSociale,
      Value<String?> adresse1,
      Value<String?> codePostal,
      Value<String?> ville,
      Value<String?> telephone,
      Value<String?> contact,
      Value<bool> actif,
      Value<String?> niveauClass,
      Value<int> rowid,
    });

class $$ClientsLocauxTableFilterComposer
    extends Composer<_$AppDatabase, $ClientsLocauxTable> {
  $$ClientsLocauxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get codeAs400 => $composableBuilder(
    column: $table.codeAs400,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get enseigne => $composableBuilder(
    column: $table.enseigne,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get raisonSociale => $composableBuilder(
    column: $table.raisonSociale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get adresse1 => $composableBuilder(
    column: $table.adresse1,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get codePostal => $composableBuilder(
    column: $table.codePostal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ville => $composableBuilder(
    column: $table.ville,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get telephone => $composableBuilder(
    column: $table.telephone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contact => $composableBuilder(
    column: $table.contact,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get actif => $composableBuilder(
    column: $table.actif,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get niveauClass => $composableBuilder(
    column: $table.niveauClass,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ClientsLocauxTableOrderingComposer
    extends Composer<_$AppDatabase, $ClientsLocauxTable> {
  $$ClientsLocauxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get codeAs400 => $composableBuilder(
    column: $table.codeAs400,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get enseigne => $composableBuilder(
    column: $table.enseigne,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get raisonSociale => $composableBuilder(
    column: $table.raisonSociale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get adresse1 => $composableBuilder(
    column: $table.adresse1,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get codePostal => $composableBuilder(
    column: $table.codePostal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ville => $composableBuilder(
    column: $table.ville,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get telephone => $composableBuilder(
    column: $table.telephone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contact => $composableBuilder(
    column: $table.contact,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get actif => $composableBuilder(
    column: $table.actif,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get niveauClass => $composableBuilder(
    column: $table.niveauClass,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ClientsLocauxTableAnnotationComposer
    extends Composer<_$AppDatabase, $ClientsLocauxTable> {
  $$ClientsLocauxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get codeAs400 =>
      $composableBuilder(column: $table.codeAs400, builder: (column) => column);

  GeneratedColumn<String> get enseigne =>
      $composableBuilder(column: $table.enseigne, builder: (column) => column);

  GeneratedColumn<String> get raisonSociale => $composableBuilder(
    column: $table.raisonSociale,
    builder: (column) => column,
  );

  GeneratedColumn<String> get adresse1 =>
      $composableBuilder(column: $table.adresse1, builder: (column) => column);

  GeneratedColumn<String> get codePostal => $composableBuilder(
    column: $table.codePostal,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ville =>
      $composableBuilder(column: $table.ville, builder: (column) => column);

  GeneratedColumn<String> get telephone =>
      $composableBuilder(column: $table.telephone, builder: (column) => column);

  GeneratedColumn<String> get contact =>
      $composableBuilder(column: $table.contact, builder: (column) => column);

  GeneratedColumn<bool> get actif =>
      $composableBuilder(column: $table.actif, builder: (column) => column);

  GeneratedColumn<String> get niveauClass => $composableBuilder(
    column: $table.niveauClass,
    builder: (column) => column,
  );
}

class $$ClientsLocauxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ClientsLocauxTable,
          ClientLocal,
          $$ClientsLocauxTableFilterComposer,
          $$ClientsLocauxTableOrderingComposer,
          $$ClientsLocauxTableAnnotationComposer,
          $$ClientsLocauxTableCreateCompanionBuilder,
          $$ClientsLocauxTableUpdateCompanionBuilder,
          (
            ClientLocal,
            BaseReferences<_$AppDatabase, $ClientsLocauxTable, ClientLocal>,
          ),
          ClientLocal,
          PrefetchHooks Function()
        > {
  $$ClientsLocauxTableTableManager(_$AppDatabase db, $ClientsLocauxTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ClientsLocauxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ClientsLocauxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ClientsLocauxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> codeAs400 = const Value.absent(),
                Value<String> enseigne = const Value.absent(),
                Value<String> raisonSociale = const Value.absent(),
                Value<String?> adresse1 = const Value.absent(),
                Value<String?> codePostal = const Value.absent(),
                Value<String?> ville = const Value.absent(),
                Value<String?> telephone = const Value.absent(),
                Value<String?> contact = const Value.absent(),
                Value<bool> actif = const Value.absent(),
                Value<String?> niveauClass = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClientsLocauxCompanion(
                id: id,
                codeAs400: codeAs400,
                enseigne: enseigne,
                raisonSociale: raisonSociale,
                adresse1: adresse1,
                codePostal: codePostal,
                ville: ville,
                telephone: telephone,
                contact: contact,
                actif: actif,
                niveauClass: niveauClass,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String codeAs400,
                required String enseigne,
                required String raisonSociale,
                Value<String?> adresse1 = const Value.absent(),
                Value<String?> codePostal = const Value.absent(),
                Value<String?> ville = const Value.absent(),
                Value<String?> telephone = const Value.absent(),
                Value<String?> contact = const Value.absent(),
                Value<bool> actif = const Value.absent(),
                Value<String?> niveauClass = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ClientsLocauxCompanion.insert(
                id: id,
                codeAs400: codeAs400,
                enseigne: enseigne,
                raisonSociale: raisonSociale,
                adresse1: adresse1,
                codePostal: codePostal,
                ville: ville,
                telephone: telephone,
                contact: contact,
                actif: actif,
                niveauClass: niveauClass,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ClientsLocauxTable, ClientLocal>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ClientsLocauxTable,
                    ClientLocal
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ClientsLocauxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ClientsLocauxTable,
      ClientLocal,
      $$ClientsLocauxTableFilterComposer,
      $$ClientsLocauxTableOrderingComposer,
      $$ClientsLocauxTableAnnotationComposer,
      $$ClientsLocauxTableCreateCompanionBuilder,
      $$ClientsLocauxTableUpdateCompanionBuilder,
      (
        ClientLocal,
        BaseReferences<_$AppDatabase, $ClientsLocauxTable, ClientLocal>,
      ),
      ClientLocal,
      PrefetchHooks Function()
    >;
typedef $$EnregistrementsLocauxTableCreateCompanionBuilder =
    EnregistrementsLocauxCompanion Function({
      required String domaine,
      required String id,
      required String json,
      Value<int> rowid,
    });
typedef $$EnregistrementsLocauxTableUpdateCompanionBuilder =
    EnregistrementsLocauxCompanion Function({
      Value<String> domaine,
      Value<String> id,
      Value<String> json,
      Value<int> rowid,
    });

class $$EnregistrementsLocauxTableFilterComposer
    extends Composer<_$AppDatabase, $EnregistrementsLocauxTable> {
  $$EnregistrementsLocauxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get domaine => $composableBuilder(
    column: $table.domaine,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EnregistrementsLocauxTableOrderingComposer
    extends Composer<_$AppDatabase, $EnregistrementsLocauxTable> {
  $$EnregistrementsLocauxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get domaine => $composableBuilder(
    column: $table.domaine,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get json => $composableBuilder(
    column: $table.json,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EnregistrementsLocauxTableAnnotationComposer
    extends Composer<_$AppDatabase, $EnregistrementsLocauxTable> {
  $$EnregistrementsLocauxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get domaine =>
      $composableBuilder(column: $table.domaine, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);
}

class $$EnregistrementsLocauxTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EnregistrementsLocauxTable,
          EnregistrementLocal,
          $$EnregistrementsLocauxTableFilterComposer,
          $$EnregistrementsLocauxTableOrderingComposer,
          $$EnregistrementsLocauxTableAnnotationComposer,
          $$EnregistrementsLocauxTableCreateCompanionBuilder,
          $$EnregistrementsLocauxTableUpdateCompanionBuilder,
          (
            EnregistrementLocal,
            BaseReferences<
              _$AppDatabase,
              $EnregistrementsLocauxTable,
              EnregistrementLocal
            >,
          ),
          EnregistrementLocal,
          PrefetchHooks Function()
        > {
  $$EnregistrementsLocauxTableTableManager(
    _$AppDatabase db,
    $EnregistrementsLocauxTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EnregistrementsLocauxTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$EnregistrementsLocauxTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$EnregistrementsLocauxTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> domaine = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> json = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => EnregistrementsLocauxCompanion(
                domaine: domaine,
                id: id,
                json: json,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String domaine,
                required String id,
                required String json,
                Value<int> rowid = const Value.absent(),
              }) => EnregistrementsLocauxCompanion.insert(
                domaine: domaine,
                id: id,
                json: json,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EnregistrementsLocauxTable, EnregistrementLocal>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $EnregistrementsLocauxTable,
                    EnregistrementLocal
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EnregistrementsLocauxTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EnregistrementsLocauxTable,
      EnregistrementLocal,
      $$EnregistrementsLocauxTableFilterComposer,
      $$EnregistrementsLocauxTableOrderingComposer,
      $$EnregistrementsLocauxTableAnnotationComposer,
      $$EnregistrementsLocauxTableCreateCompanionBuilder,
      $$EnregistrementsLocauxTableUpdateCompanionBuilder,
      (
        EnregistrementLocal,
        BaseReferences<
          _$AppDatabase,
          $EnregistrementsLocauxTable,
          EnregistrementLocal
        >,
      ),
      EnregistrementLocal,
      PrefetchHooks Function()
    >;
typedef $$PhotosLocalesTableCreateCompanionBuilder =
    PhotosLocalesCompanion Function({
      required String id,
      required Uint8List octets,
      Value<DateTime> majLe,
      Value<int> rowid,
    });
typedef $$PhotosLocalesTableUpdateCompanionBuilder =
    PhotosLocalesCompanion Function({
      Value<String> id,
      Value<Uint8List> octets,
      Value<DateTime> majLe,
      Value<int> rowid,
    });

class $$PhotosLocalesTableFilterComposer
    extends Composer<_$AppDatabase, $PhotosLocalesTable> {
  $$PhotosLocalesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get octets => $composableBuilder(
    column: $table.octets,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get majLe => $composableBuilder(
    column: $table.majLe,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PhotosLocalesTableOrderingComposer
    extends Composer<_$AppDatabase, $PhotosLocalesTable> {
  $$PhotosLocalesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get octets => $composableBuilder(
    column: $table.octets,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get majLe => $composableBuilder(
    column: $table.majLe,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PhotosLocalesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PhotosLocalesTable> {
  $$PhotosLocalesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<Uint8List> get octets =>
      $composableBuilder(column: $table.octets, builder: (column) => column);

  GeneratedColumn<DateTime> get majLe =>
      $composableBuilder(column: $table.majLe, builder: (column) => column);
}

class $$PhotosLocalesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PhotosLocalesTable,
          PhotoLocale,
          $$PhotosLocalesTableFilterComposer,
          $$PhotosLocalesTableOrderingComposer,
          $$PhotosLocalesTableAnnotationComposer,
          $$PhotosLocalesTableCreateCompanionBuilder,
          $$PhotosLocalesTableUpdateCompanionBuilder,
          (
            PhotoLocale,
            BaseReferences<_$AppDatabase, $PhotosLocalesTable, PhotoLocale>,
          ),
          PhotoLocale,
          PrefetchHooks Function()
        > {
  $$PhotosLocalesTableTableManager(_$AppDatabase db, $PhotosLocalesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PhotosLocalesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PhotosLocalesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PhotosLocalesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<Uint8List> octets = const Value.absent(),
                Value<DateTime> majLe = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PhotosLocalesCompanion(
                id: id,
                octets: octets,
                majLe: majLe,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required Uint8List octets,
                Value<DateTime> majLe = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PhotosLocalesCompanion.insert(
                id: id,
                octets: octets,
                majLe: majLe,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PhotosLocalesTable, PhotoLocale>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PhotosLocalesTable,
                    PhotoLocale
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PhotosLocalesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PhotosLocalesTable,
      PhotoLocale,
      $$PhotosLocalesTableFilterComposer,
      $$PhotosLocalesTableOrderingComposer,
      $$PhotosLocalesTableAnnotationComposer,
      $$PhotosLocalesTableCreateCompanionBuilder,
      $$PhotosLocalesTableUpdateCompanionBuilder,
      (
        PhotoLocale,
        BaseReferences<_$AppDatabase, $PhotosLocalesTable, PhotoLocale>,
      ),
      PhotoLocale,
      PrefetchHooks Function()
    >;
typedef $$PhotosVisiteTableCreateCompanionBuilder =
    PhotosVisiteCompanion Function({
      Value<int> id,
      required String visiteId,
      required String etape,
      required Uint8List octets,
      Value<DateTime> priseLe,
    });
typedef $$PhotosVisiteTableUpdateCompanionBuilder =
    PhotosVisiteCompanion Function({
      Value<int> id,
      Value<String> visiteId,
      Value<String> etape,
      Value<Uint8List> octets,
      Value<DateTime> priseLe,
    });

class $$PhotosVisiteTableFilterComposer
    extends Composer<_$AppDatabase, $PhotosVisiteTable> {
  $$PhotosVisiteTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get visiteId => $composableBuilder(
    column: $table.visiteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etape => $composableBuilder(
    column: $table.etape,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get octets => $composableBuilder(
    column: $table.octets,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get priseLe => $composableBuilder(
    column: $table.priseLe,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PhotosVisiteTableOrderingComposer
    extends Composer<_$AppDatabase, $PhotosVisiteTable> {
  $$PhotosVisiteTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get visiteId => $composableBuilder(
    column: $table.visiteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etape => $composableBuilder(
    column: $table.etape,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get octets => $composableBuilder(
    column: $table.octets,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get priseLe => $composableBuilder(
    column: $table.priseLe,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PhotosVisiteTableAnnotationComposer
    extends Composer<_$AppDatabase, $PhotosVisiteTable> {
  $$PhotosVisiteTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get visiteId =>
      $composableBuilder(column: $table.visiteId, builder: (column) => column);

  GeneratedColumn<String> get etape =>
      $composableBuilder(column: $table.etape, builder: (column) => column);

  GeneratedColumn<Uint8List> get octets =>
      $composableBuilder(column: $table.octets, builder: (column) => column);

  GeneratedColumn<DateTime> get priseLe =>
      $composableBuilder(column: $table.priseLe, builder: (column) => column);
}

class $$PhotosVisiteTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PhotosVisiteTable,
          PhotoVisiteLocale,
          $$PhotosVisiteTableFilterComposer,
          $$PhotosVisiteTableOrderingComposer,
          $$PhotosVisiteTableAnnotationComposer,
          $$PhotosVisiteTableCreateCompanionBuilder,
          $$PhotosVisiteTableUpdateCompanionBuilder,
          (
            PhotoVisiteLocale,
            BaseReferences<
              _$AppDatabase,
              $PhotosVisiteTable,
              PhotoVisiteLocale
            >,
          ),
          PhotoVisiteLocale,
          PrefetchHooks Function()
        > {
  $$PhotosVisiteTableTableManager(_$AppDatabase db, $PhotosVisiteTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PhotosVisiteTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PhotosVisiteTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PhotosVisiteTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> visiteId = const Value.absent(),
                Value<String> etape = const Value.absent(),
                Value<Uint8List> octets = const Value.absent(),
                Value<DateTime> priseLe = const Value.absent(),
              }) => PhotosVisiteCompanion(
                id: id,
                visiteId: visiteId,
                etape: etape,
                octets: octets,
                priseLe: priseLe,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String visiteId,
                required String etape,
                required Uint8List octets,
                Value<DateTime> priseLe = const Value.absent(),
              }) => PhotosVisiteCompanion.insert(
                id: id,
                visiteId: visiteId,
                etape: etape,
                octets: octets,
                priseLe: priseLe,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PhotosVisiteTable, PhotoVisiteLocale>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PhotosVisiteTable,
                    PhotoVisiteLocale
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PhotosVisiteTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PhotosVisiteTable,
      PhotoVisiteLocale,
      $$PhotosVisiteTableFilterComposer,
      $$PhotosVisiteTableOrderingComposer,
      $$PhotosVisiteTableAnnotationComposer,
      $$PhotosVisiteTableCreateCompanionBuilder,
      $$PhotosVisiteTableUpdateCompanionBuilder,
      (
        PhotoVisiteLocale,
        BaseReferences<_$AppDatabase, $PhotosVisiteTable, PhotoVisiteLocale>,
      ),
      PhotoVisiteLocale,
      PrefetchHooks Function()
    >;
typedef $$EnvoisEnAttenteTableCreateCompanionBuilder =
    EnvoisEnAttenteCompanion Function({
      Value<int> id,
      required String utilisateurId,
      required String type,
      required String cle,
      required String payload,
      Value<String?> refLocale,
      Value<String?> serveurId,
      Value<String> etat,
      Value<int> essais,
      Value<String?> derniereErreur,
      Value<DateTime> creeLe,
      Value<DateTime> misAJourLe,
      Value<DateTime?> envoyeLe,
    });
typedef $$EnvoisEnAttenteTableUpdateCompanionBuilder =
    EnvoisEnAttenteCompanion Function({
      Value<int> id,
      Value<String> utilisateurId,
      Value<String> type,
      Value<String> cle,
      Value<String> payload,
      Value<String?> refLocale,
      Value<String?> serveurId,
      Value<String> etat,
      Value<int> essais,
      Value<String?> derniereErreur,
      Value<DateTime> creeLe,
      Value<DateTime> misAJourLe,
      Value<DateTime?> envoyeLe,
    });

class $$EnvoisEnAttenteTableFilterComposer
    extends Composer<_$AppDatabase, $EnvoisEnAttenteTable> {
  $$EnvoisEnAttenteTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get utilisateurId => $composableBuilder(
    column: $table.utilisateurId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cle => $composableBuilder(
    column: $table.cle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get refLocale => $composableBuilder(
    column: $table.refLocale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serveurId => $composableBuilder(
    column: $table.serveurId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etat => $composableBuilder(
    column: $table.etat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get essais => $composableBuilder(
    column: $table.essais,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get derniereErreur => $composableBuilder(
    column: $table.derniereErreur,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get creeLe => $composableBuilder(
    column: $table.creeLe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get misAJourLe => $composableBuilder(
    column: $table.misAJourLe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get envoyeLe => $composableBuilder(
    column: $table.envoyeLe,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EnvoisEnAttenteTableOrderingComposer
    extends Composer<_$AppDatabase, $EnvoisEnAttenteTable> {
  $$EnvoisEnAttenteTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get utilisateurId => $composableBuilder(
    column: $table.utilisateurId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cle => $composableBuilder(
    column: $table.cle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get refLocale => $composableBuilder(
    column: $table.refLocale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serveurId => $composableBuilder(
    column: $table.serveurId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etat => $composableBuilder(
    column: $table.etat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get essais => $composableBuilder(
    column: $table.essais,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get derniereErreur => $composableBuilder(
    column: $table.derniereErreur,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get creeLe => $composableBuilder(
    column: $table.creeLe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get misAJourLe => $composableBuilder(
    column: $table.misAJourLe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get envoyeLe => $composableBuilder(
    column: $table.envoyeLe,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EnvoisEnAttenteTableAnnotationComposer
    extends Composer<_$AppDatabase, $EnvoisEnAttenteTable> {
  $$EnvoisEnAttenteTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get utilisateurId => $composableBuilder(
    column: $table.utilisateurId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get cle =>
      $composableBuilder(column: $table.cle, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get refLocale =>
      $composableBuilder(column: $table.refLocale, builder: (column) => column);

  GeneratedColumn<String> get serveurId =>
      $composableBuilder(column: $table.serveurId, builder: (column) => column);

  GeneratedColumn<String> get etat =>
      $composableBuilder(column: $table.etat, builder: (column) => column);

  GeneratedColumn<int> get essais =>
      $composableBuilder(column: $table.essais, builder: (column) => column);

  GeneratedColumn<String> get derniereErreur => $composableBuilder(
    column: $table.derniereErreur,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get creeLe =>
      $composableBuilder(column: $table.creeLe, builder: (column) => column);

  GeneratedColumn<DateTime> get misAJourLe => $composableBuilder(
    column: $table.misAJourLe,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get envoyeLe =>
      $composableBuilder(column: $table.envoyeLe, builder: (column) => column);
}

class $$EnvoisEnAttenteTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EnvoisEnAttenteTable,
          EnvoiLocal,
          $$EnvoisEnAttenteTableFilterComposer,
          $$EnvoisEnAttenteTableOrderingComposer,
          $$EnvoisEnAttenteTableAnnotationComposer,
          $$EnvoisEnAttenteTableCreateCompanionBuilder,
          $$EnvoisEnAttenteTableUpdateCompanionBuilder,
          (
            EnvoiLocal,
            BaseReferences<_$AppDatabase, $EnvoisEnAttenteTable, EnvoiLocal>,
          ),
          EnvoiLocal,
          PrefetchHooks Function()
        > {
  $$EnvoisEnAttenteTableTableManager(
    _$AppDatabase db,
    $EnvoisEnAttenteTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EnvoisEnAttenteTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EnvoisEnAttenteTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EnvoisEnAttenteTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> utilisateurId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> cle = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String?> refLocale = const Value.absent(),
                Value<String?> serveurId = const Value.absent(),
                Value<String> etat = const Value.absent(),
                Value<int> essais = const Value.absent(),
                Value<String?> derniereErreur = const Value.absent(),
                Value<DateTime> creeLe = const Value.absent(),
                Value<DateTime> misAJourLe = const Value.absent(),
                Value<DateTime?> envoyeLe = const Value.absent(),
              }) => EnvoisEnAttenteCompanion(
                id: id,
                utilisateurId: utilisateurId,
                type: type,
                cle: cle,
                payload: payload,
                refLocale: refLocale,
                serveurId: serveurId,
                etat: etat,
                essais: essais,
                derniereErreur: derniereErreur,
                creeLe: creeLe,
                misAJourLe: misAJourLe,
                envoyeLe: envoyeLe,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String utilisateurId,
                required String type,
                required String cle,
                required String payload,
                Value<String?> refLocale = const Value.absent(),
                Value<String?> serveurId = const Value.absent(),
                Value<String> etat = const Value.absent(),
                Value<int> essais = const Value.absent(),
                Value<String?> derniereErreur = const Value.absent(),
                Value<DateTime> creeLe = const Value.absent(),
                Value<DateTime> misAJourLe = const Value.absent(),
                Value<DateTime?> envoyeLe = const Value.absent(),
              }) => EnvoisEnAttenteCompanion.insert(
                id: id,
                utilisateurId: utilisateurId,
                type: type,
                cle: cle,
                payload: payload,
                refLocale: refLocale,
                serveurId: serveurId,
                etat: etat,
                essais: essais,
                derniereErreur: derniereErreur,
                creeLe: creeLe,
                misAJourLe: misAJourLe,
                envoyeLe: envoyeLe,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EnvoisEnAttenteTable, EnvoiLocal>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $EnvoisEnAttenteTable,
                    EnvoiLocal
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EnvoisEnAttenteTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EnvoisEnAttenteTable,
      EnvoiLocal,
      $$EnvoisEnAttenteTableFilterComposer,
      $$EnvoisEnAttenteTableOrderingComposer,
      $$EnvoisEnAttenteTableAnnotationComposer,
      $$EnvoisEnAttenteTableCreateCompanionBuilder,
      $$EnvoisEnAttenteTableUpdateCompanionBuilder,
      (
        EnvoiLocal,
        BaseReferences<_$AppDatabase, $EnvoisEnAttenteTable, EnvoiLocal>,
      ),
      EnvoiLocal,
      PrefetchHooks Function()
    >;
typedef $$EnvoisFichiersTableCreateCompanionBuilder =
    EnvoisFichiersCompanion Function({
      Value<int> id,
      required int envoiId,
      Value<int?> photoId,
      required String etape,
      required String idApk,
      Value<String> etat,
      Value<String?> derniereErreur,
    });
typedef $$EnvoisFichiersTableUpdateCompanionBuilder =
    EnvoisFichiersCompanion Function({
      Value<int> id,
      Value<int> envoiId,
      Value<int?> photoId,
      Value<String> etape,
      Value<String> idApk,
      Value<String> etat,
      Value<String?> derniereErreur,
    });

class $$EnvoisFichiersTableFilterComposer
    extends Composer<_$AppDatabase, $EnvoisFichiersTable> {
  $$EnvoisFichiersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get envoiId => $composableBuilder(
    column: $table.envoiId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get photoId => $composableBuilder(
    column: $table.photoId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etape => $composableBuilder(
    column: $table.etape,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get idApk => $composableBuilder(
    column: $table.idApk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etat => $composableBuilder(
    column: $table.etat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get derniereErreur => $composableBuilder(
    column: $table.derniereErreur,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EnvoisFichiersTableOrderingComposer
    extends Composer<_$AppDatabase, $EnvoisFichiersTable> {
  $$EnvoisFichiersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get envoiId => $composableBuilder(
    column: $table.envoiId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get photoId => $composableBuilder(
    column: $table.photoId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etape => $composableBuilder(
    column: $table.etape,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get idApk => $composableBuilder(
    column: $table.idApk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etat => $composableBuilder(
    column: $table.etat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get derniereErreur => $composableBuilder(
    column: $table.derniereErreur,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EnvoisFichiersTableAnnotationComposer
    extends Composer<_$AppDatabase, $EnvoisFichiersTable> {
  $$EnvoisFichiersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get envoiId =>
      $composableBuilder(column: $table.envoiId, builder: (column) => column);

  GeneratedColumn<int> get photoId =>
      $composableBuilder(column: $table.photoId, builder: (column) => column);

  GeneratedColumn<String> get etape =>
      $composableBuilder(column: $table.etape, builder: (column) => column);

  GeneratedColumn<String> get idApk =>
      $composableBuilder(column: $table.idApk, builder: (column) => column);

  GeneratedColumn<String> get etat =>
      $composableBuilder(column: $table.etat, builder: (column) => column);

  GeneratedColumn<String> get derniereErreur => $composableBuilder(
    column: $table.derniereErreur,
    builder: (column) => column,
  );
}

class $$EnvoisFichiersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EnvoisFichiersTable,
          EnvoiFichierLocal,
          $$EnvoisFichiersTableFilterComposer,
          $$EnvoisFichiersTableOrderingComposer,
          $$EnvoisFichiersTableAnnotationComposer,
          $$EnvoisFichiersTableCreateCompanionBuilder,
          $$EnvoisFichiersTableUpdateCompanionBuilder,
          (
            EnvoiFichierLocal,
            BaseReferences<
              _$AppDatabase,
              $EnvoisFichiersTable,
              EnvoiFichierLocal
            >,
          ),
          EnvoiFichierLocal,
          PrefetchHooks Function()
        > {
  $$EnvoisFichiersTableTableManager(
    _$AppDatabase db,
    $EnvoisFichiersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EnvoisFichiersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EnvoisFichiersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EnvoisFichiersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> envoiId = const Value.absent(),
                Value<int?> photoId = const Value.absent(),
                Value<String> etape = const Value.absent(),
                Value<String> idApk = const Value.absent(),
                Value<String> etat = const Value.absent(),
                Value<String?> derniereErreur = const Value.absent(),
              }) => EnvoisFichiersCompanion(
                id: id,
                envoiId: envoiId,
                photoId: photoId,
                etape: etape,
                idApk: idApk,
                etat: etat,
                derniereErreur: derniereErreur,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int envoiId,
                Value<int?> photoId = const Value.absent(),
                required String etape,
                required String idApk,
                Value<String> etat = const Value.absent(),
                Value<String?> derniereErreur = const Value.absent(),
              }) => EnvoisFichiersCompanion.insert(
                id: id,
                envoiId: envoiId,
                photoId: photoId,
                etape: etape,
                idApk: idApk,
                etat: etat,
                derniereErreur: derniereErreur,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EnvoisFichiersTable, EnvoiFichierLocal>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $EnvoisFichiersTable,
                    EnvoiFichierLocal
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EnvoisFichiersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EnvoisFichiersTable,
      EnvoiFichierLocal,
      $$EnvoisFichiersTableFilterComposer,
      $$EnvoisFichiersTableOrderingComposer,
      $$EnvoisFichiersTableAnnotationComposer,
      $$EnvoisFichiersTableCreateCompanionBuilder,
      $$EnvoisFichiersTableUpdateCompanionBuilder,
      (
        EnvoiFichierLocal,
        BaseReferences<_$AppDatabase, $EnvoisFichiersTable, EnvoiFichierLocal>,
      ),
      EnvoiFichierLocal,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$MetaBaseTableTableManager get metaBase =>
      $$MetaBaseTableTableManager(_db, _db.metaBase);
  $$ArticlesLocauxTableTableManager get articlesLocaux =>
      $$ArticlesLocauxTableTableManager(_db, _db.articlesLocaux);
  $$ClientsLocauxTableTableManager get clientsLocaux =>
      $$ClientsLocauxTableTableManager(_db, _db.clientsLocaux);
  $$EnregistrementsLocauxTableTableManager get enregistrementsLocaux =>
      $$EnregistrementsLocauxTableTableManager(_db, _db.enregistrementsLocaux);
  $$PhotosLocalesTableTableManager get photosLocales =>
      $$PhotosLocalesTableTableManager(_db, _db.photosLocales);
  $$PhotosVisiteTableTableManager get photosVisite =>
      $$PhotosVisiteTableTableManager(_db, _db.photosVisite);
  $$EnvoisEnAttenteTableTableManager get envoisEnAttente =>
      $$EnvoisEnAttenteTableTableManager(_db, _db.envoisEnAttente);
  $$EnvoisFichiersTableTableManager get envoisFichiers =>
      $$EnvoisFichiersTableTableManager(_db, _db.envoisFichiers);
}
