import 'package:flutter/material.dart';
import 'package:flutter_zustand/flutter_zustand.dart';

abstract class PersistentStore<T> extends Store<T> {
  PersistentStore(super.initialState) {
    _init();
  }

  Future<void> _init() async {
    final loaded = await load();
    if (loaded != null) {
      set(loaded);
    }
  }

  Future<T?> load();

  Future<void> save(T state);

  @override
  @mustCallSuper
  Future<void> dispose() async {
    await save(state);
    await super.dispose();
  }
}
