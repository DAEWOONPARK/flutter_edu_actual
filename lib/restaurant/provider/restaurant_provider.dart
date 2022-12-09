import 'package:actual/common/model/cursor_pagination_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../model/restaurant_model.dart';
import '../repository/restaurant_repository.dart';

final restaurantProvider =
    StateNotifierProvider<RestaurantStateNotifier, CursorPaginationBase>(
        (ref) {
  final repository = ref.watch(restaurantRepositoryProvider);
  final notifier = RestaurantStateNotifier(repository: repository);
  return notifier;
});

class RestaurantStateNotifier extends StateNotifier<CursorPaginationBase> {
  final RestaurantRepository repository;

  RestaurantStateNotifier({
    required this.repository,
  }) : super(CursorPaginationLoading()) {
    paginate(); // Class가 인스턴스화 되는 순간에 paginate() 함수를 실행할 수 있다. 즉, state 안에 값들을 저장할 수 있다.
  }

  paginate() async {
    final resp = await repository.paginate();
    state = resp;
  }
}
