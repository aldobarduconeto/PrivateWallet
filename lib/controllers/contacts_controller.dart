import 'package:flutter/foundation.dart';

import '../models/networks.dart';
import '../models/wallet_contact.dart';
import '../services/storage/contact_store.dart';

/// Agenda de destinatários, persistida no armazenamento seguro.
class ContactsController extends ValueNotifier<List<WalletContact>> {
  /// Inicializa [ContactsController] com os dados recebidos.
  ContactsController({ContactStore? store})
    : _store = store ?? ContactStore(),
      super(const []);

  final ContactStore _store;
  bool _loaded = false;

  /// Retorna `loaded` para consulta em contatos.
  bool get loaded => _loaded;

  /// Lê os dados persistidos e prepara o estado em memória.
  Future<void> load() async {
    final contacts = await _store.load()
      ..sort(_byName);
    value = List.unmodifiable(contacts);
    _loaded = true;
  }

  /// Verifica se o contato tem endereço compatível com a rede selecionada.
  List<WalletContact> compatibleWith(BitcoinChain? chain) =>
      value.where((contact) => contact.matches(chain)).toList();

  /// Procura o contato correspondente ao endereço e à rede informados.
  WalletContact? find(String address, BitcoinChain? chain) {
    final target = address.toLowerCase();
    for (final contact in value) {
      if (contact.matches(chain)) {
        if (contact.address.toLowerCase() == target ||
            contact.effectiveEth.toLowerCase() == target ||
            contact.effectiveBtc.toLowerCase() == target) {
          return contact;
        }
      }
    }
    return null;
  }

  /// Localiza `by unique id` no fluxo de contatos.
  WalletContact? findByUniqueId(String uniqueId) {
    final clean = uniqueId.trim().toUpperCase();
    for (final contact in value) {
      if (contact.uniqueId?.toUpperCase() == clean) {
        return contact;
      }
    }
    return null;
  }

  /// Localiza `by username` no fluxo de contatos.
  WalletContact? findByUsername(String username) {
    final clean = username.trim().toLowerCase();
    for (final contact in value) {
      if (contact.username?.toLowerCase() == clean) {
        return contact;
      }
    }
    return null;
  }

  /// Adiciona o registro informado e persiste a lista atualizada.
  Future<void> add(WalletContact contact) async {
    if (value.any(contact.sameDestination)) {
      throw const FormatException('Este contato/endereço já está na agenda.');
    }
    await _save([...value, contact]);
  }

  /// Adiciona `or update` no fluxo de contatos.
  Future<void> addOrUpdate(WalletContact contact) async {
    final existingIndex = value.indexWhere(contact.sameDestination);
    if (existingIndex >= 0) {
      final updated = [...value];
      updated[existingIndex] = contact;
      await _save(updated);
    } else {
      await _save([...value, contact]);
    }
  }

  /// Atualiza o registro selecionado no armazenamento.
  Future<void> update(
    WalletContact oldContact,
    WalletContact newContact,
  ) async {
    final updated = value
        .map((c) => c.sameDestination(oldContact) ? newContact : c)
        .toList();
    await _save(updated);
  }

  /// Remove o registro selecionado e atualiza a lista.
  Future<void> remove(WalletContact contact) =>
      _save(value.where((item) => !item.sameDestination(contact)).toList());

  /// Persiste os dados para uso nas próximas sessões.
  Future<void> _save(List<WalletContact> contacts) async {
    contacts.sort(_byName);
    await _store.save(contacts);
    value = List.unmodifiable(contacts);
  }

  /// Localiza o valor associado ao nome persistido.
  static int _byName(WalletContact a, WalletContact b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());
}
