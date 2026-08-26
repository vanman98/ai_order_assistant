import 'package:ai_order_assistant/core/di/app_providers.dart';
import 'package:ai_order_assistant/features/debts/data/datasources/debts_remote_datasource.dart';
import 'package:ai_order_assistant/features/debts/data/repositories/debts_repository_impl.dart';
import 'package:ai_order_assistant/features/debts/domain/repositories/debts_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final debtsRemoteDataSourceProvider = Provider<DebtsRemoteDataSource>((ref) {
  return DebtsRemoteDataSource(ref.watch(apiClientProvider));
});

final debtsRepositoryProvider = Provider<DebtsRepository>((ref) {
  return DebtsRepositoryImpl(ref.watch(debtsRemoteDataSourceProvider));
});
