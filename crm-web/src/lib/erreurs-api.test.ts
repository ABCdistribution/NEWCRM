import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { messageApi, messageErreurApi, messagesApi, messagesDuCorps, traduireMessageApi } from './erreurs-api';

// Aucun réseau : les réponses d'erreur de l'API sont fabriquées avec `new Response(...)` (objet local de Node).

const GENERIQUE = 'Certaines informations saisies sont invalides. Vérifiez le formulaire.';

describe('traduireMessageApi : contraintes class-validator connues', () => {
  it.each([
    ['portable must be shorter than or equal to 20 characters', 'Le champ « téléphone portable » ne doit pas dépasser 20 caractères.'],
    ['nom must be longer than or equal to 2 characters', 'Le champ « nom » doit contenir au moins 2 caractères.'],
    ['nom should not be empty', 'Le champ « nom » est obligatoire.'],
    ['mail must be an email', 'Adresse e-mail invalide.'],
    ['clientId must be a UUID', 'Identifiant invalide.'],
    ['datePassage must be a valid ISO 8601 date string', 'Le champ « date de passage » doit être une date valide.'],
    ['recurrence must not be less than 1', 'Le champ « recurrence » doit être supérieur ou égal à 1.'],
    ['recurrence must not be greater than 8', 'Le champ « recurrence » doit être inférieur ou égal à 8.'],
    ['titre must be a string', 'La valeur du champ « titre » est invalide.'],
    ['property foo should not exist', 'Champ non reconnu : « foo ».'],
  ])('« %s »', (brut, attendu) => {
    expect(traduireMessageApi(brut)).toBe(attendu);
  });

  it('un champ inconnu garde son nom technique', () => {
    expect(traduireMessageApi('zzz should not be empty')).toBe('Le champ « zzz » est obligatoire.');
  });
});

describe('traduireMessageApi : messages hors contraintes connues', () => {
  it('un message métier français est relayé tel quel', () => {
    expect(traduireMessageApi('Ce magasin est déjà planifié ce jour-là pour ce promoteur')).toBe(
      'Ce magasin est déjà planifié ce jour-là pour ce promoteur',
    );
    expect(traduireMessageApi('imageUrl doit être une URL http(s) ou un chemin commençant par /')).toBe(
      'imageUrl doit être une URL http(s) ou un chemin commençant par /',
    );
  });

  it("un message de validation anglais inconnu est masqué (jamais affiché brut)", () => {
    expect(traduireMessageApi('soireeLieu must match /^[a-z]+$/ regular expression')).toBe(GENERIQUE);
    expect(traduireMessageApi('each value in jours must be a positive number')).toBe(GENERIQUE);
  });

  it('les espaces autour du message sont retirés', () => {
    expect(traduireMessageApi('  Cible invalide  ')).toBe('Cible invalide');
  });
});

describe('messagesDuCorps', () => {
  it('liste de messages NestJS : traduits, sans doublon', () => {
    expect(messagesDuCorps({ message: ['mail must be an email', 'mail must be an email', 'nom should not be empty'] })).toEqual([
      'Adresse e-mail invalide.',
      'Le champ « nom » est obligatoire.',
    ]);
  });

  it('message unique (chaîne)', () => {
    expect(messagesDuCorps({ message: 'Date invalide' })).toEqual(['Date invalide']);
  });

  it.each([null, undefined, 'texte', 42, {}, { message: 12 }, { message: [] }, { message: ['', '  ', 3] }])(
    'corps inexploitable (%j) : aucun message',
    (corps) => {
      expect(messagesDuCorps(corps)).toEqual([]);
    },
  );
});

describe('messagesApi / messageApi (corps d\'une réponse)', () => {
  const reponse = (corps: string, status = 400) => new Response(corps, { status });

  it('lit le premier message et le traduit', async () => {
    const res = reponse(JSON.stringify({ statusCode: 400, message: ['portable must be shorter than or equal to 20 characters'] }));
    expect(await messageApi(res)).toBe('Le champ « téléphone portable » ne doit pas dépasser 20 caractères.');
  });

  it('corps non JSON : aucun message, l\'appelant garde son message par défaut', async () => {
    expect(await messagesApi(reponse('<html>Bad Gateway</html>', 502))).toEqual([]);
    expect(await messageApi(reponse('', 500))).toBeNull();
  });
});

describe('messageErreurApi (le STATUT décide du message)', () => {
  const reponse = (status: number, corps: unknown = null) =>
    new Response(corps === null ? null : JSON.stringify(corps), { status });

  beforeEach(() => {
    vi.spyOn(console, 'error').mockImplementation(() => undefined);
  });
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('401 : session expirée', async () => {
    expect(await messageErreurApi(reponse(401, { message: 'Unauthorized' }), 'test')).toBe('Session expirée : reconnectez-vous.');
  });

  it.each([500, 502, 503])('%i : texte fixe, le message de l\'API n\'est JAMAIS relayé', async (statut) => {
    const message = await messageErreurApi(reponse(statut, { message: 'ENOENT: /srv/crm/import/clients.csv' }), 'test');

    expect(message).toBe(`Le serveur a rencontré une erreur (code ${statut}). Réessayez dans un instant.`);
    expect(message).not.toContain('ENOENT');
  });

  it('5xx : seul le statut est journalisé, avec le contexte', async () => {
    await messageErreurApi(reponse(500, { message: 'secret interne' }), 'prospects');

    expect(console.error).toHaveBeenCalledTimes(1);
    expect(vi.mocked(console.error).mock.calls[0].join(' ')).toContain('[prospects]');
    expect(vi.mocked(console.error).mock.calls[0].join(' ')).not.toContain('secret interne');
  });

  it('400 : message de l\'API, traduit', async () => {
    expect(await messageErreurApi(reponse(400, { message: ['email must be an email'] }), 'test')).toBe('Adresse e-mail invalide.');
  });

  it('400 : message métier français relayé tel quel', async () => {
    expect(await messageErreurApi(reponse(409, { message: 'Ce prospect est déjà converti.' }), 'test')).toBe('Ce prospect est déjà converti.');
  });

  it('4xx sans corps exploitable : message par défaut avec le code', async () => {
    expect(await messageErreurApi(reponse(404), 'test')).toBe('Requête refusée (code 404).');
  });
});
