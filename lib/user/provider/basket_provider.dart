import 'package:actual/product/model/product_model.dart';
import 'package:actual/user/model/basket_item_model.dart';
import 'package:actual/user/model/patch_basket_body.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:collection/collection.dart';

import '../repository/user_me_repository.dart';

final basketProvider =
    StateNotifierProvider<BasketProvider, List<BasketItemModel>>((ref) {
      final repository = ref.watch(userMeRepositoryProvider);
  return BasketProvider(repository: repository);
});

class BasketProvider extends StateNotifier<List<BasketItemModel>> {
  final UserMeRepository repository;

  BasketProvider({required this.repository,}) : super([]);

  Future<void> patchBasket() async {
    await repository.patchBasket(
        body: PatchBasketBody(
          basket: state.map((e) =>
              PatchBasketBodyBasket(productId: e.product.id, count: e.count,)
          ).toList(),
        )
    );
  }

  Future<void> addToBasket({
    required ProductModel product,
  }) async {
    // 1) 아직 장바구니에 해당되는 상품이 없다면, 장바구니에 상품을 추가한다.
    // 2) 만약에 이미 들어있다면, 장바구니에 있는 값에 +1을 한다.

    final exists =
        state.firstWhereOrNull((e) => e.product.id == product.id) != null;

    if (exists) {
      state = state
          .map(
            (e) =>
        e.product.id == product.id ? e.copyWith(count: e.count + 1) : e,
      )
          .toList();
    } else {
      state = [...state, BasketItemModel(product: product, count: 1)];
    }

    // 에러가 발생할 가능성이 작고, 에러가 나더라도 큰 문제가 없다면
    // 굳이 캐싱 업데이트를 서버 요청 후에 하는 것보단, 캐싱 업데이트를 먼저 해주는게
    // 사용자에게 빠르게 동작하는 앱이라는 경험할 수 있게 한다.
    // -> Optimistic Response(긍정적 응답): 응답이 성공할 것이라고 가정하고 상태를 먼저 업데이트 함
    await patchBasket();

    Future<void> removeFromBasket({
      required ProductModel product,
      // true이면 count와 관계없이 삭제한다.
      bool isDelete = false,
    }) async {
      // 1) 장바구니에 상품이 존재할 때
      //    1) 상품의 카운트가 1보다 크면 -1한다.
      //    2) 상품의 카운트가 1이면 삭제한다.
      // 2) 상품이 존재하지 않을 때, 즉시 함수 반환하고 아무것도 하지 않는다.

      final exists =
          state.firstWhereOrNull((e) => e.product.id == product.id) != null;

      if (!exists) {
        return;
      }

      final existingProduct = state.firstWhere((e) =>
      e.product.id == product.id);

      if (existingProduct.count == 1 || isDelete) {
        state = state
            .where(
              (e) => e.product.id != product.id,
        )
            .toList();
      } else {
        state = state
            .map(
              (e) =>
          e.product.id == product.id
              ? e.copyWith(
            count: e.count - 1,
          )
              : e,
        )
            .toList();
      }
      await patchBasket();
    }
  }
}
