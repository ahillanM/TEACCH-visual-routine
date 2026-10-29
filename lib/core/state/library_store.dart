import 'package:flutter/foundation.dart';

import '../models/library_items.dart';

/// The organisational library: reusable activities, places and contacts.
class LibraryStore extends ChangeNotifier {
  final List<LibraryActivity> _activities;
  final List<Place> _places;
  final List<Contact> _contacts;

  LibraryStore({
    required List<LibraryActivity> activities,
    required List<Place> places,
    required List<Contact> contacts,
  })  : _activities = [...activities],
        _places = [...places],
        _contacts = [...contacts];

  List<LibraryActivity> get activities => List.unmodifiable(_activities);
  List<Place> get places => List.unmodifiable(_places);
  List<Contact> get contacts => List.unmodifiable(_contacts);

  Place? place(String? id) =>
      id == null ? null : _places.where((p) => p.id == id).firstOrNull;

  Contact? contact(String? id) =>
      id == null ? null : _contacts.where((c) => c.id == id).firstOrNull;

  LibraryActivity? activity(String? id) =>
      id == null ? null : _activities.where((a) => a.id == id).firstOrNull;

  String placeName(String? id) => place(id)?.name ?? 'No place set';
  String contactName(String? id) => contact(id)?.name ?? 'No person set';

  void addActivity(LibraryActivity activity) {
    _activities.add(activity);
    notifyListeners();
  }

  void addPlace(Place place) {
    _places.add(place);
    notifyListeners();
  }

  void addContact(Contact contact) {
    _contacts.add(contact);
    notifyListeners();
  }
}
