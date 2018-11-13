Require Import
        List
        ZArith.
Require Import
        Events
        LibModel
        Maps
        Messages
        States
        Types.
Require Import
        BrokerRegistry
        OrderRegistry
        TradeDelegate.


Open Scope bool_scope.


Module SpendableElem <: ElemType.
  Definition elt := Spendable.
  Definition elt_zero := mk_spendable false O O.
  Definition elt_eq := fun (x x': elt) => x = x'.

  Lemma elt_eq_dec:
    forall (x y: elt), { x = y } + { ~ x = y }.
  Proof.
  Admitted.

  Lemma elt_eq_refl:
    forall x, elt_eq x x.
  Proof.
    unfold elt_eq; auto.
  Qed.

  Lemma elt_eq_symm:
    forall x y, elt_eq x y -> elt_eq y x.
  Proof.
    unfold elt_eq; auto.
  Qed.

  Lemma elt_eq_trans:
    forall x y, elt_eq x y -> forall z, elt_eq y z -> elt_eq x z.
  Proof.
    unfold elt_eq; intros; congruence.
  Qed.

End SpendableElem.

Module SpendableMap := Mapping AAA_as_DT SpendableElem.


Module RingSubmitter.

  Section RunTimeState.

    (* Order in Loopring contract is composed of two parts. One is the *)
    (*      static data from submitter, while the other is dynamically *)
    (*      generated and used only in LPSC. *)

    (*      `Order` in Coq defines the static part. `OrderRuntimeState` *)
    (*      combines it and the dynamic parts together. *)
    (*    *)
    Record OrderRuntimeState :=
      mk_order_runtime_state {
          ord_rt_order: Order;

          ord_rt_p2p: bool;
          ord_rt_hash: bytes32;
          ord_rt_brokerInterceptor: address;
          ord_rt_filledAmountS : uint;
          ord_rt_initialFilledAmountS: uint;
          ord_rt_valid: bool;
        }.

    (* Similarly for Mining. *)
    Record MiningRuntimeState :=
      mk_mining_runtime_state {
          mining_rt_static: Mining;
          mining_rt_hash: bytes32;
          mining_rt_interceptor: address;
        }.

    Record Participation :=
      mk_participation {
          part_order_idx: nat; (* index in another order list *)
          part_splitS: uint;
          part_feeAmount: uint;
          part_feeAmountS: uint;
          part_feeAmountB: uint;
          part_rebateFee: uint;
          part_rebateS: uint;
          part_rebateB: uint;
          part_fillAmountS: uint;
          part_fillAmountB: uint;
        }.

    Record RingRuntimeState :=
      mk_ring_runtime_state {
          ring_rt_static: Ring;
          ring_rt_participations: list Participation;
          ring_rt_hash: bytes32;
          ring_rt_valid: bool;
        }.

    (* `RingSubmitterState` models the state of RingSubmitter state *)
    (*      observable from the outside of contract. *)

    (*      `RingSubmitterRuntimeState` also models the state (e.g., memory) *)
    (*      that is only visible within the contract in its execution. *)
    (*    *)
    Record RingSubmitterRuntimeState :=
      mk_ring_submitter_runtime_state {
          submitter_rt_mining: MiningRuntimeState;
          submitter_rt_orders: list OrderRuntimeState;
          submitter_rt_rings: list RingRuntimeState;
          submitter_rt_spendables: SpendableMap.t;
          (* TODO: add necessary fields of Context *)
        }.


    Definition make_rt_order (order: Order): OrderRuntimeState :=
      {|
        ord_rt_order := order;
        ord_rt_p2p := false;
        ord_rt_hash := 0;
        ord_rt_brokerInterceptor := 0;
        ord_rt_filledAmountS := 0;
        ord_rt_initialFilledAmountS := 0;
        ord_rt_valid := true;
      |}.

    Fixpoint make_rt_orders (orders: list Order): list OrderRuntimeState :=
      match orders with
      | nil => nil
      | order :: orders => make_rt_order order :: make_rt_orders orders
      end.

    Definition make_rt_mining (mining: Mining): MiningRuntimeState :=
      {|
        mining_rt_static := mining;
        mining_rt_hash := 0;
        mining_rt_interceptor := 0;
      |}.

    Definition make_participation (ord_idx: nat): Participation :=
      {|
        part_order_idx := ord_idx;
        part_splitS := 0;
        part_feeAmount := 0;
        part_feeAmountS := 0;
        part_feeAmountB := 0;
        part_rebateFee := 0;
        part_rebateS := 0;
        part_rebateB := 0;
        part_fillAmountS := 0;
        part_fillAmountB := 0;
      |}.

    Fixpoint make_participations (ord_indices: list nat): list Participation :=
      match ord_indices with
      | nil => nil
      | idx :: indices' => make_participation idx :: make_participations indices'
      end.

    Definition make_rt_ring (ring: Ring): RingRuntimeState :=
      {|
        ring_rt_static := ring;
        ring_rt_participations := make_participations (ring_orders ring);
        ring_rt_hash := 0;
        ring_rt_valid := true;
      |}.

    Fixpoint make_rt_rings (rings: list Ring): list RingRuntimeState :=
      match rings with
      | nil => nil
      | ring :: rings => make_rt_ring ring :: make_rt_rings rings
      end.

    Definition make_rt_submitter_state
               (mining: Mining) (orders: list Order) (rings: list Ring)
      : RingSubmitterRuntimeState :=
      {|
        submitter_rt_mining := make_rt_mining mining;
        submitter_rt_orders := make_rt_orders orders;
        submitter_rt_rings := make_rt_rings rings;
        submitter_rt_spendables := SpendableMap.empty;
      |}.

    Definition submitter_update_mining
               (rsst: RingSubmitterRuntimeState) (st: MiningRuntimeState)
      : RingSubmitterRuntimeState :=
      {|
        submitter_rt_mining := st;
        submitter_rt_orders := submitter_rt_orders rsst;
        submitter_rt_rings := submitter_rt_rings rsst;
        submitter_rt_spendables := submitter_rt_spendables rsst;
      |}.

    Definition submitter_update_orders
               (rsst: RingSubmitterRuntimeState) (sts: list OrderRuntimeState)
      : RingSubmitterRuntimeState :=
      {|
        submitter_rt_mining := submitter_rt_mining rsst;
        submitter_rt_orders := sts;
        submitter_rt_rings := submitter_rt_rings rsst;
        submitter_rt_spendables := submitter_rt_spendables rsst;
      |}.

    Definition submitter_update_rings
               (rsst: RingSubmitterRuntimeState) (sts: list RingRuntimeState)
      : RingSubmitterRuntimeState :=
      {|
        submitter_rt_mining := submitter_rt_mining rsst;
        submitter_rt_orders := submitter_rt_orders rsst;
        submitter_rt_rings := sts;
        submitter_rt_spendables := submitter_rt_spendables rsst;
      |}.

    Definition submitter_update_spendables
               (rsst: RingSubmitterRuntimeState) (spendables: SpendableMap.t)
      : RingSubmitterRuntimeState :=
      {|
        submitter_rt_mining := submitter_rt_mining rsst;
        submitter_rt_orders := submitter_rt_orders rsst;
        submitter_rt_rings := submitter_rt_rings rsst;
        submitter_rt_spendables := spendables;
      |}.

    Definition upd_order_broker
               (ord: OrderRuntimeState) (broker: address)
      : OrderRuntimeState :=
      let order := ord_rt_order ord in
      {|
        ord_rt_order :=
          {|
            order_version               := order_version               order;
            order_owner                 := order_owner                 order;
            order_tokenS                := order_tokenS                order;
            order_tokenB                := order_tokenB                order;
            order_amountS               := order_amountS               order;
            order_amountB               := order_amountB               order;
            order_validSince            := order_validSince            order;
            order_tokenSpendableS       := order_tokenSpendableS       order;
            order_tokenSpendableFee     := order_tokenSpendableFee     order;
            order_dualAuthAddr          := order_dualAuthAddr          order;
            order_broker                := broker;
            order_brokerSpendableS      := order_brokerSpendableS      order;
            order_brokerSpendableFee    := order_brokerSpendableFee    order;
            order_orderInterceptor      := order_orderInterceptor      order;
            order_wallet                := order_wallet                order;
            order_validUntil            := order_validUntil            order;
            order_sig                   := order_sig                   order;
            order_dualAuthSig           := order_dualAuthSig           order;
            order_allOrNone             := order_allOrNone             order;
            order_feeToken              := order_feeToken              order;
            order_feeAmount             := order_feeAmount             order;
            order_feePercentage         := order_feePercentage         order;
            order_waiveFeePercentage    := order_waiveFeePercentage    order;
            order_tokenSFeePercentage   := order_tokenSFeePercentage   order;
            order_tokenBFeePercentage   := order_tokenBFeePercentage   order;
            order_tokenRecipient        := order_tokenRecipient        order;
            order_walletSplitPercentage := order_walletSplitPercentage order;
          |};
        ord_rt_p2p                  := ord_rt_p2p ord;
        ord_rt_hash                 := ord_rt_hash ord;
        ord_rt_brokerInterceptor    := ord_rt_brokerInterceptor ord;
        ord_rt_filledAmountS        := ord_rt_filledAmountS ord;
        ord_rt_initialFilledAmountS := ord_rt_initialFilledAmountS ord;
        ord_rt_valid                := ord_rt_valid ord;
      |}.

    Definition upd_order_interceptor
               (ord: OrderRuntimeState) (interceptor: address)
      : OrderRuntimeState :=
      {|
        ord_rt_order                := ord_rt_order ord;
        ord_rt_p2p                  := ord_rt_p2p ord;
        ord_rt_hash                 := ord_rt_hash ord;
        ord_rt_brokerInterceptor    := interceptor;
        ord_rt_filledAmountS        := ord_rt_filledAmountS ord;
        ord_rt_initialFilledAmountS := ord_rt_initialFilledAmountS ord;
        ord_rt_valid                := ord_rt_valid ord;
      |}.

    Definition upd_order_valid
               (ord: OrderRuntimeState) (valid: bool)
      : OrderRuntimeState :=
      {|
        ord_rt_order                := ord_rt_order ord;
        ord_rt_p2p                  := ord_rt_p2p ord;
        ord_rt_hash                 := ord_rt_hash ord;
        ord_rt_brokerInterceptor    := ord_rt_brokerInterceptor ord;
        ord_rt_filledAmountS        := ord_rt_filledAmountS ord;
        ord_rt_initialFilledAmountS := ord_rt_initialFilledAmountS ord;
        ord_rt_valid                := valid;
      |}.

    Definition upd_order_init_filled
               (ord: OrderRuntimeState) (amount: uint)
      : OrderRuntimeState :=
      {|
        ord_rt_order                := ord_rt_order ord;
        ord_rt_p2p                  := ord_rt_p2p ord;
        ord_rt_hash                 := ord_rt_hash ord;
        ord_rt_brokerInterceptor    := ord_rt_brokerInterceptor ord;
        ord_rt_filledAmountS        := ord_rt_filledAmountS ord;
        ord_rt_initialFilledAmountS := amount;
        ord_rt_valid                := ord_rt_valid ord;
      |}.

    Definition upd_order_filled
               (ord: OrderRuntimeState) (amount: uint)
      : OrderRuntimeState :=
      {|
        ord_rt_order                := ord_rt_order ord;
        ord_rt_p2p                  := ord_rt_p2p ord;
        ord_rt_hash                 := ord_rt_hash ord;
        ord_rt_brokerInterceptor    := ord_rt_brokerInterceptor ord;
        ord_rt_filledAmountS        := amount;
        ord_rt_initialFilledAmountS := ord_rt_initialFilledAmountS ord;
        ord_rt_valid                := ord_rt_valid ord;
      |}.

    Definition upd_order_p2p
               (ord: OrderRuntimeState) (p2p: bool)
      : OrderRuntimeState :=
      {|
        ord_rt_order                := ord_rt_order ord;
        ord_rt_p2p                  := p2p;
        ord_rt_hash                 := ord_rt_hash ord;
        ord_rt_brokerInterceptor    := ord_rt_brokerInterceptor ord;
        ord_rt_filledAmountS        := ord_rt_filledAmountS ord;
        ord_rt_initialFilledAmountS := ord_rt_initialFilledAmountS ord;
        ord_rt_valid                := ord_rt_valid ord;
      |}.

    Definition clear_order_broker_spendables
               (ord: OrderRuntimeState)
      : OrderRuntimeState :=
      let order := ord_rt_order ord in
      {|
        ord_rt_order :=
          {|
            order_version               := order_version               order;
            order_owner                 := order_owner                 order;
            order_tokenS                := order_tokenS                order;
            order_tokenB                := order_tokenB                order;
            order_amountS               := order_amountS               order;
            order_amountB               := order_amountB               order;
            order_validSince            := order_validSince            order;
            order_tokenSpendableS       := order_tokenSpendableS       order;
            order_tokenSpendableFee     := order_tokenSpendableFee     order;
            order_dualAuthAddr          := order_dualAuthAddr          order;
            order_broker                := order_broker                order;
            order_brokerSpendableS      := mk_spendable false 0 0;
            order_brokerSpendableFee    := mk_spendable false 0 0;
            order_orderInterceptor      := order_orderInterceptor      order;
            order_wallet                := order_wallet                order;
            order_validUntil            := order_validUntil            order;
            order_sig                   := order_sig                   order;
            order_dualAuthSig           := order_dualAuthSig           order;
            order_allOrNone             := order_allOrNone             order;
            order_feeToken              := order_feeToken              order;
            order_feeAmount             := order_feeAmount             order;
            order_feePercentage         := order_feePercentage         order;
            order_waiveFeePercentage    := order_waiveFeePercentage    order;
            order_tokenSFeePercentage   := order_tokenSFeePercentage   order;
            order_tokenBFeePercentage   := order_tokenBFeePercentage   order;
            order_tokenRecipient        := order_tokenRecipient        order;
            order_walletSplitPercentage := order_walletSplitPercentage order;
          |};
        ord_rt_p2p                  := ord_rt_p2p ord;
        ord_rt_hash                 := ord_rt_hash ord;
        ord_rt_brokerInterceptor    := ord_rt_brokerInterceptor ord;
        ord_rt_filledAmountS        := ord_rt_filledAmountS ord;
        ord_rt_initialFilledAmountS := ord_rt_initialFilledAmountS ord;
        ord_rt_valid                := ord_rt_valid ord;
      |}.

    Definition upd_ring_hash
               (r: RingRuntimeState) (hash: bytes32)
      : RingRuntimeState :=
      {|
        ring_rt_static         := ring_rt_static r;
        ring_rt_participations := ring_rt_participations r;
        ring_rt_hash           := hash;
        ring_rt_valid          := ring_rt_valid r;
      |}.

    Definition upd_ring_valid
               (r: RingRuntimeState) (valid: bool)
      : RingRuntimeState :=
      {|
        ring_rt_static         := ring_rt_static r;
        ring_rt_participations := ring_rt_participations r;
        ring_rt_hash           := ring_rt_hash r;
        ring_rt_valid          := valid;
      |}.

    Definition upd_mining_hash
               (m: MiningRuntimeState) (hash: bytes32)
      : MiningRuntimeState :=
      {|
        mining_rt_static      := mining_rt_static m;
        mining_rt_hash        := hash;
        mining_rt_interceptor := mining_rt_interceptor m;
      |}.

    Definition upd_mining_interceptor
               (m: MiningRuntimeState) (interceptor: address)
      : MiningRuntimeState :=
      {|
        mining_rt_static      := mining_rt_static m;
        mining_rt_hash        := mining_rt_hash m;
        mining_rt_interceptor := interceptor;
      |}.

    Definition upd_mining_miner
               (m: MiningRuntimeState) (miner: address)
      : MiningRuntimeState :=
      let mining := mining_rt_static m in
      {|
        mining_rt_static      :=
          {|
            mining_feeRecipient := mining_feeRecipient mining;
            mining_miner        := miner;
            mining_sig          := mining_sig mining;
          |};
        mining_rt_hash        := mining_rt_hash m;
        mining_rt_interceptor := mining_rt_interceptor m;
      |}.

  End RunTimeState.

  Parameters get_order_hash: Order -> bytes32.
  Parameters get_ring_hash: Ring -> list OrderRuntimeState -> bytes32.
  Parameter get_mining_hash: Mining -> list RingRuntimeState -> bytes32.

  Section HashAxioms.

    Definition get_order_hash_preimg (order: Order) :=
      (order_allOrNone order,
       order_tokenBFeePercentage order,
       order_tokenSFeePercentage order,
       order_feePercentage order,
       order_walletSplitPercentage order,
       order_feeToken order,
       order_tokenRecipient order,
       order_wallet order,
       order_orderInterceptor order,
       order_broker order,
       order_dualAuthAddr order,
       order_tokenB order,
       order_tokenS order,
       order_owner order,
       order_validUntil order,
       order_validSince order,
       order_feeAmount order,
       order_amountB order,
       order_amountS order).

    Axiom order_hash_dec:
      forall (ord ord': Order),
        let preimg := get_order_hash_preimg ord in
        let preimg' := get_order_hash_preimg ord' in
        (preimg = preimg' -> get_order_hash ord = get_order_hash ord') /\
        (preimg <> preimg' -> get_order_hash ord <> get_order_hash ord').

    Fixpoint __get_ring_hash_preimg
             (indices: list nat) (orders: list OrderRuntimeState)
      : list (option (bytes32 * int16)):=
      match indices with
      | nil => nil
      | idx :: indices' =>
        let preimg := match nth_error orders idx with
                      | None => None
                      | Some order => Some (ord_rt_hash order,
                                           order_waiveFeePercentage (ord_rt_order order))
                      end
        in preimg :: __get_ring_hash_preimg indices' orders
      end.

    Definition get_ring_hash_preimg
               (r: Ring) (orders: list OrderRuntimeState) :=
      __get_ring_hash_preimg (ring_orders r) orders.

    Axiom ring_hash_dec:
      forall (r r': Ring) (orders orders': list OrderRuntimeState),
        let preimg := get_ring_hash_preimg r orders in
        let preimg' := get_ring_hash_preimg r' orders' in
        (preimg = preimg' -> get_ring_hash r orders = get_ring_hash r' orders') /\
        (preimg <> preimg' -> get_ring_hash r orders <> get_ring_hash r' orders').

    Fixpoint rings_hashes (rings: list RingRuntimeState) : list bytes32 :=
      match rings with
      | nil => nil
      | r :: rings' => ring_rt_hash r :: rings_hashes rings'
      end.

    Definition get_mining_hash_preimg
               (mining: Mining) (rings: list RingRuntimeState) :=
      (mining_miner mining, mining_feeRecipient mining, rings_hashes rings).

    Axiom mining_hash_dec:
      forall (m m': Mining) (rings rings': list RingRuntimeState),
        let preimg := get_mining_hash_preimg m rings in
        let preimg' := get_mining_hash_preimg m' rings' in
        (preimg = preimg' -> get_mining_hash m rings = get_mining_hash m' rings') /\
        (preimg <> preimg' -> get_mining_hash m rings <> get_mining_hash m' rings').

  End HashAxioms.

  Section SubSpec.

    Record SubSpec :=
      mk_sub_spec {
          subspec_require: WorldState -> RingSubmitterRuntimeState -> Prop;
          subspec_trans: WorldState -> RingSubmitterRuntimeState ->
                         WorldState -> RingSubmitterRuntimeState ->
                         Prop;
          subspec_events: WorldState -> RingSubmitterRuntimeState ->
                          list Event -> Prop;
        }.

  End SubSpec.

  Section SubmitRings.

    Section UpdateOrdersHashes.

      Fixpoint update_orders_hashes
               (orders: list OrderRuntimeState)
      : list OrderRuntimeState :=
        match orders with
        | nil => nil
        | order :: orders' =>
          let order' := {|
                ord_rt_order := ord_rt_order order;
                ord_rt_p2p := ord_rt_p2p order;
                ord_rt_hash := get_order_hash (ord_rt_order order);
                ord_rt_brokerInterceptor := ord_rt_brokerInterceptor order;
                ord_rt_filledAmountS := ord_rt_filledAmountS order;
                ord_rt_initialFilledAmountS := ord_rt_initialFilledAmountS order;
                ord_rt_valid := ord_rt_valid order;
              |}
          in order' :: update_orders_hashes orders'
        end.

      Definition update_orders_hashes_subspec
                 (sender: address)
                 (orders: list Order)
                 (rings: list Ring)
                 (mining: Mining) :=
        {|
          subspec_require :=
            fun wst st => True;

          subspec_trans :=
            fun wst st wst' st' =>
              wst' = wst /\
              st' = submitter_update_orders
                      st (update_orders_hashes (submitter_rt_orders st));

          subspec_events :=
            fun wst st events => events = nil;
        |}.

    End UpdateOrdersHashes.

    Section UpdateOrdersBrokersAndIntercetors.

      Definition get_broker_success
                 (wst: WorldState) (ord: OrderRuntimeState)
                 (wst': WorldState) (retval: option address) (events: list Event)
      : Prop :=
        let order := ord_rt_order ord in
        BrokerRegistry.model
          wst
          (msg_getBroker (wst_ring_submitter_addr wst)
                         (order_owner order) (order_broker order))
          wst' (RetBrokerInterceptor retval) events.

      Inductive update_order_broker_interceptor
                (wst: WorldState) (ord: OrderRuntimeState)
        : WorldState -> OrderRuntimeState -> list Event -> Prop :=
      | UpdateBrokerInterceptor_P2P:
          let order := ord_rt_order ord in
          order_broker order = O ->
          update_order_broker_interceptor
            wst ord wst (upd_order_broker ord (order_owner order)) nil

      | UpdateBrokerInterceptor_NonP2P_registered:
          forall wst' interceptor events,
            get_broker_success wst ord wst' (Some interceptor) events ->
            update_order_broker_interceptor wst ord wst' ord events

      | UpdateBrokerInterceptor_NonP2P_unregistered:
          forall wst' events,
            get_broker_success wst ord wst' None events ->
            update_order_broker_interceptor
              wst ord wst' (upd_order_valid ord false) events
      .

      Inductive update_orders_broker_interceptor (wst: WorldState)
        : list OrderRuntimeState ->
          WorldState -> list OrderRuntimeState -> list Event -> Prop :=
      | UpdateOrdersBrokerInterceptor_nil:
          update_orders_broker_interceptor wst nil wst nil nil

      | UpdateOrdersBrokerInterceptor_cons:
          forall order orders wst' order' events wst'' orders' events',
            update_order_broker_interceptor wst order wst' order' events ->
            update_orders_broker_interceptor wst' orders wst'' orders' events' ->
            update_orders_broker_interceptor
              wst (order :: orders) wst'' (order' :: orders') (events ++ events')
      .

      Definition update_orders_brokers_and_interceptors
                 (sender: address)
                 (orders: list Order)
                 (rings: list Ring)
                 (mining: Mining) :=
        {|
          subspec_require :=
            fun wst st => True;

          subspec_trans :=
            fun wst st wst' st' =>
              forall wst'' orders' events,
                update_orders_broker_interceptor
                  wst (submitter_rt_orders st) wst'' orders' events ->
                wst' = wst'' /\
                st' = submitter_update_orders st orders'
          ;

          subspec_events :=
            fun wst st events =>
              forall wst' orders' events',
                update_orders_broker_interceptor
                  wst (submitter_rt_orders st) wst' orders' events' ->
                events = events'
          ;
        |}.

    End UpdateOrdersBrokersAndIntercetors.

    Section GetFilledAndCheckCancelled.

      Fixpoint make_order_params
               (orders: list OrderRuntimeState) : list OrderParam :=
        match orders with
        | nil => nil
        | order :: orders' =>
          let static_order := ord_rt_order order in
          let param :=
              {|
                order_param_broker := order_broker static_order;
                order_param_owner  := order_owner static_order;
                order_param_hash   := ord_rt_hash order;
                order_param_validSince := order_validSince static_order;
                order_param_tradingPair := Nat.lxor (order_tokenS static_order) (order_tokenB static_order);
              |}
          in param :: make_order_params orders'
        end.

      Definition batchGetFilledAndCheckCancelled_success
                 (wst: WorldState) (st: RingSubmitterRuntimeState)
                 (fills: list (option uint))
                 (wst': WorldState) (events: list Event) : Prop :=
        TradeDelegate.model
          wst
          (msg_batchGetFilledAndCheckCancelled
             (wst_ring_submitter_addr wst)
             (make_order_params (submitter_rt_orders st)))
          wst' (RetFills fills) events.

      Inductive update_order_filled_and_valid (order: OrderRuntimeState)
        : option uint -> OrderRuntimeState -> Prop :=
      | UpdateOrderFilledAndValid_noncancelled:
          forall amount,
            update_order_filled_and_valid
              order (Some amount)
              (upd_order_filled (upd_order_init_filled order amount) amount)

      | UpdateOrderFilledAndValid_cancelled:
          update_order_filled_and_valid order None (upd_order_valid order false)
      .

      Inductive update_orders_filled_and_valid
        : list OrderRuntimeState (* orders in pre-state *) ->
          list (option uint)     (* argument fills *) ->
          list OrderRuntimeState (* orders in post-state *) ->
          Prop :=
      | UpdateOrdersFilledAndValid_nil:
          update_orders_filled_and_valid nil nil nil

      | UpdateOrdersFilledAndValid_cons:
          forall order orders fill fills order' orders',
            update_order_filled_and_valid order fill order' ->
            update_orders_filled_and_valid orders fills orders' ->
            update_orders_filled_and_valid
              (order :: orders) (fill :: fills) (order' :: orders')
      .

      Definition get_filled_and_check_cancelled_subspec
                 (sender: address)
                 (orders: list Order)
                 (rings: list Ring)
                 (mining: Mining) :=
        {|
          subspec_require :=
            fun wst st =>
              forall fills wst' events,
                batchGetFilledAndCheckCancelled_success wst st fills wst' events ->
                length fills = length (submitter_rt_orders st)
          ;

          subspec_trans :=
            fun wst st wst' st' =>
              forall fills wst'' events,
                batchGetFilledAndCheckCancelled_success wst st fills wst'' events ->
                wst' = wst'' /\
                forall orders',
                  update_orders_filled_and_valid (submitter_rt_orders st) fills orders' ->
                  st' = submitter_update_orders st orders'
          ;

          subspec_events :=
            fun wst st events =>
              forall fills wst' events',
                batchGetFilledAndCheckCancelled_success wst st fills wst' events' ->
                events = events'
          ;
        |}.

    End GetFilledAndCheckCancelled.

    Section UpdateBrokerSpendable.

      Definition get_order_tokenS_spendable
                 (st: RingSubmitterRuntimeState) (ord: OrderRuntimeState) :=
        let order := ord_rt_order ord in
        let broker := order_broker order in
        let owner := order_owner order in
        let token := order_tokenS order in
        SpendableMap.get (submitter_rt_spendables st) (broker, owner, token).

      Definition get_order_feeToken_spendable
                 (st: RingSubmitterRuntimeState) (ord: OrderRuntimeState) :=
        let order := ord_rt_order ord in
        let broker := order_broker order in
        let owner := order_owner order in
        let token := order_feeToken order in
        SpendableMap.get (submitter_rt_spendables st) (broker, owner, token).

    End UpdateBrokerSpendable.

    Section CheckOrders.

      Definition is_order_valid (ord: OrderRuntimeState) (now: uint) : bool :=
        let order := ord_rt_order ord in
        (* if order.filledAmountS == 0 then ... *)
        (implb (Nat.eqb (ord_rt_filledAmountS ord) O)
               ((Nat.eqb (order_version order) 0) &&
               (negb (Nat.eqb (order_owner order) 0)) &&
               (negb (Nat.eqb (order_tokenS order) 0)) &&
               (negb (Nat.eqb (order_tokenB order) 0)) &&
               (negb (Nat.eqb (order_amountS order) 0)) &&
               (negb (Nat.eqb (order_feeToken order) 0)) &&
               (Nat.ltb (order_feePercentage order) FEE_PERCENTAGE_BASE_N) &&
               (Nat.ltb (order_tokenSFeePercentage order) FEE_PERCENTAGE_BASE_N) &&
               (Nat.ltb (order_tokenBFeePercentage order) FEE_PERCENTAGE_BASE_N) &&
               (Nat.leb (order_walletSplitPercentage order) 100) &&
               (Nat.leb (order_validSince order) now)
               (* TODO: model signature check *))) &&
        (* common check *)
        (Nat.eqb (order_validUntil order) 0 || Nat.ltb now (order_validUntil order)) &&
        (Z.leb (order_waiveFeePercentage order) FEE_PERCENTAGE_BASE_Z) &&
        (Z.leb (- FEE_PERCENTAGE_BASE_Z) (order_waiveFeePercentage order)) &&
        (Nat.eqb (order_dualAuthAddr order) 0 || Nat.ltb 0 (length (order_dualAuthSig order))) &&
        (ord_rt_valid ord).

      Fixpoint update_orders_valid (orders: list OrderRuntimeState) (now: uint)
        : list OrderRuntimeState :=
        match orders with
        | nil => nil
        | order :: orders' =>
          upd_order_valid order (is_order_valid order now) :: update_orders_valid orders' now
        end.

      Definition is_order_p2p (ord: OrderRuntimeState) : bool :=
        let order := ord_rt_order ord in
        (Nat.ltb 0 (order_tokenSFeePercentage order)) ||
        (Nat.ltb 0 (order_tokenBFeePercentage order)).

      Fixpoint update_orders_p2p (orders: list OrderRuntimeState)
        : list OrderRuntimeState :=
        match orders with
        | nil => nil
        | order :: orders' =>
          upd_order_p2p order (is_order_p2p order) :: update_orders_p2p orders'
        end.

      Definition check_orders_subspec
                 (sender: address)
                 (orders: list Order)
                 (rings: list Ring)
                 (mining: Mining) :=
        {|
          subspec_require :=
            fun wst st => True;

          subspec_trans :=
            fun wst st wst' st' =>
              wst' = wst /\
              let orders' := update_orders_valid
                               (submitter_rt_orders st)
                               (block_timestamp (wst_block_state wst)) in
              let orders' := update_orders_p2p orders' in
              st' = submitter_update_orders st orders';

          subspec_events :=
            fun wst st events =>
              events = nil;
        |}.

    End CheckOrders.

    Section UpdateRingsHashes.

      Fixpoint update_rings_hash
               (rings: list RingRuntimeState) (orders: list OrderRuntimeState)
      : list RingRuntimeState :=
        match rings with
        | nil => nil
        | r :: rings' =>
          upd_ring_hash r (get_ring_hash (ring_rt_static r) orders) ::
          update_rings_hash rings' orders
        end.

      Definition update_rings_hash_subspec
                 (sender: address)
                 (orders: list Order)
                 (rings: list Ring)
                 (mining: Mining) :=
        {|
          subspec_require :=
            fun wst st => True;

          subspec_trans :=
            fun wst st wst' st' =>
              wst' = wst /\
              st' = submitter_update_rings
                      st
                      (update_rings_hash
                         (submitter_rt_rings st) (submitter_rt_orders st));

          subspec_events :=
            fun wst st events => events = nil;
        |}.

    End UpdateRingsHashes.

    Section UpdateMiningHash.

      Definition update_mining_hash
                 (mining: MiningRuntimeState) (rings: list RingRuntimeState)
      : MiningRuntimeState :=
        upd_mining_hash mining (get_mining_hash (mining_rt_static mining) rings).

      Definition update_mining_hash_subspec
                 (sender: address)
                 (orders: list Order)
                 (rings: list Ring)
                 (mining: Mining) :=
        {|
          subspec_require :=
            fun wst st => True;

          subspec_trans :=
            fun wst st wst' st' =>
              wst' = wst /\
              st' = submitter_update_mining
                      st
                      (update_mining_hash
                         (submitter_rt_mining st) (submitter_rt_rings st));

          subspec_events :=
            fun wst st events => events = nil;
        |}.

    End UpdateMiningHash.

    Section UpdateMinerAndInterceptor.

    Definition update_miner_interceptor (st: RingSubmitterRuntimeState) :=
      let mining := submitter_rt_mining st in
      let static_mining := mining_rt_static mining in
      match mining_miner static_mining with
      | O => submitter_update_mining
              st (upd_mining_miner mining (mining_feeRecipient static_mining))
      | _ => st
      end.

      Definition update_miner_interceptor_subspec
                 (sender: address)
                 (_orders: list Order)
                 (_rings: list Ring)
                 (_mining: Mining) :=
        {|
          subspec_require :=
            fun wst st => True;

          subspec_trans :=
            fun wst st wst' st' =>
              wst' = wst /\
              st' = update_miner_interceptor st;

          subspec_events :=
            fun wst st events => events = nil;
        |}.

    End UpdateMinerAndInterceptor.

    Definition SubmitRingsSubSpec :=
      address -> list Order -> list Ring -> Mining -> SubSpec.

    Definition submit_rings_subspec_seq (_spec _spec': SubmitRingsSubSpec) : SubmitRingsSubSpec :=
      fun sender orders rings mining =>
        let spec := _spec sender orders rings mining in
        let spec' := _spec' sender orders rings mining in
        {|
          subspec_require :=
            fun wst st =>
              subspec_require spec wst st /\
              forall wst' st',
                subspec_trans spec wst st wst' st' ->
                subspec_require spec' wst' st';

          subspec_trans :=
            fun wst st wst' st' =>
              forall wst'' st'',
                subspec_trans spec wst st wst'' st'' /\
                subspec_trans spec' wst'' st'' wst' st';

          subspec_events :=
            fun wst st events =>
              forall wst' st' events' events'',
                subspec_trans spec wst st wst' st' ->
                subspec_events spec wst st events' ->
                subspec_events spec' wst' st' events'' ->
                events = events' ++ events'';
        |}.
    Notation "s ;; s'" := (submit_rings_subspec_seq s s') (left associativity, at level 400).

    Definition submit_rings_subspec_to_fspec
               (subspec: SubmitRingsSubSpec)
               (sender: address) (orders: list Order) (rings: list Ring) (mining: Mining)
      : FSpec :=
      let spec := subspec sender orders rings mining in
      let st := make_rt_submitter_state mining orders rings in
      {|
        fspec_require :=
          fun wst => subspec_require spec wst st;

        fspec_trans :=
          fun wst wst' retval =>
            retval = RetNone /\
            forall wst'' st'',
              subspec_trans spec wst st wst'' st'' ->
              wst' = wst'';

        fspec_events :=
          fun wst events =>
              subspec_events spec wst st events;
      |}.

    Definition submitRings_spec
               (sender: address)
               (orders: list Order) (rings: list Ring) (mining: Mining) :=
      submit_rings_subspec_to_fspec
        (
           update_orders_hashes_subspec ;;
           update_orders_brokers_and_interceptors ;;
           get_filled_and_check_cancelled_subspec ;;
           check_orders_subspec ;;
           update_rings_hash_subspec ;;
           update_mining_hash_subspec ;;
           update_miner_interceptor_subspec
        )
        sender orders rings mining.

  End SubmitRings.

  Definition get_spec (msg: RingSubmitterMsg) : FSpec :=
    match msg with
    | msg_submitRings sender orders rings mining =>
      submitRings_spec sender orders rings mining
    end.

  Definition model
             (wst: WorldState)
             (msg: RingSubmitterMsg)
             (wst': WorldState)
             (retval: RetVal)
             (events: list Event)
    : Prop :=
    fspec_sat (get_spec msg) wst wst' retval events.

End RingSubmitter.



(*   Context `{verify_signature: address -> bytes32 -> bytes -> bool}. *)

(*   Section CheckMinerSignature. *)

(*     Definition check_miner_signature *)
(*                (wst0 wst: WorldState) (sender: address) (st: RingSubmitterRuntimeState) *)
(*     : WorldState * RingSubmitterRuntimeState * list Event := *)
(*       let mining := submitter_rt_mining st in *)
(*       let static_mining := mining_rt_static mining in *)
(*       let miner := mining_miner static_mining in *)
(*       let sig := mining_sig static_mining in *)
(*       match sig with *)
(*       | nil => if Nat.eqb sender miner then *)
(*                 (wst, st, nil) *)
(*               else *)
(*                 (wst0, st, EvtRevert :: nil) *)
(*       | _ => if verify_signature miner (mining_rt_hash mining) sig then *)
(*               (wst, st, nil) *)
(*             else *)
(*               (wst0, st, EvtRevert :: nil) *)
(*       end. *)

(*   End CheckMinerSignature. *)


(*   Section CheckOrdersDualSig. *)

(*     Fixpoint __check_orders_dualsig *)
(*              (orders: list OrderRuntimeState) (mining_hash: bytes32) *)
(*     : list OrderRuntimeState := *)
(*       match orders with *)
(*       | nil => nil *)
(*       | order :: orders' => *)
(*         let static_order := ord_rt_order order in *)
(*         let order' := *)
(*             match order_dualAuthSig static_order with *)
(*             | nil => order *)
(*             | _ => if verify_signature (order_dualAuthAddr static_order) *)
(*                                       mining_hash *)
(*                                       (order_dualAuthSig static_order) *)
(*                   then *)
(*                     order *)
(*                   else *)
(*                     upd_order_valid order false *)
(*             end *)
(*         in order' :: __check_orders_dualsig orders' mining_hash *)
(*       end. *)

(*     Definition check_orders_dualsig *)
(*                (wst0 wst: WorldState) (sender: address) (st: RingSubmitterRuntimeState) *)
(*       : WorldState * RingSubmitterRuntimeState * list Event := *)
(*       let orders := submitter_rt_orders st in *)
(*       let mining_hash := mining_rt_hash (submitter_rt_mining st) in *)
(*       (wst, *)
(*        submitter_update_orders st (__check_orders_dualsig orders mining_hash), *)
(*        nil). *)

(*   End CheckOrdersDualSig. *)


(*   Definition submitter_seq *)
(*              (f0 f1: WorldState -> WorldState -> address -> RingSubmitterRuntimeState -> *)
(*                      WorldState * RingSubmitterRuntimeState * list Event) := *)
(*     fun (wst0 wst: WorldState) (sender: address) (st: RingSubmitterRuntimeState) => *)
(*       match f0 wst0 wst sender st with *)
(*       | (wst', st', evts') => *)
(*         if has_revert_event evts' then *)
(*           (wst0, st, EvtRevert :: nil) *)
(*         else *)
(*           match f1 wst0 wst' sender st' with *)
(*           | (wst'', st'', evts'') => *)
(*             if has_revert_event evts'' then *)
(*               (wst0, st, EvtRevert :: nil) *)
(*             else *)
(*               (wst'', st'', evts' ++ evts'') *)
(*           end *)
(*       end. *)

(*   Notation "f0 ';;' f1" := (submitter_seq f0 f1) (left associativity, at level 400). *)

(*   Definition func_submitRings *)
(*              (wst0 wst: WorldState) *)
(*              (sender: address) *)
(*              (orders: list Order) (rings: list Ring) (mining: Mining) *)
(*     : (WorldState * RetVal * list Event) := *)
(*     let st := make_rt_submitter_state mining orders rings in *)
(*     match (update_orders_hash ;; *)
(*            update_orders_broker_interceptor ;; *)
(*            get_filled_and_check_cancelled ;; *)
(*            update_broker_spendables ;; *)
(*            check_orders ;; *)
(*            update_rings_hash ;; *)
(*            update_mining_hash ;; *)
(*            update_miner_interceptor ;; *)
(*            check_miner_signature ;; *)
(*            check_orders_dualsig) wst0 wst sender st *)
(*     with *)
(*     | (wst', st', evts') => *)
(*       if has_revert_event evts' then *)
(*         (wst0, RetNone, EvtRevert :: nil) *)
(*       else *)
(*         (wst', RetNone, evts') *)
(*     end. *)

(* End Func_submitRings. *)


(* Parameter order_hash: Order -> bytes32. *)
(* Parameter order_hash_dec: forall ord ord': Order, *)
(*     (get_order_hash_preimg ord = get_order_hash_preimg ord' -> order_hash ord = order_hash ord') /\ *)
(*     (get_order_hash_preimg ord <> get_order_hash_preimg ord' -> order_hash ord <> order_hash ord'). *)
(* Parameter ring_hash: RingRuntimeState -> list OrderRuntimeState -> bytes32. *)
(* Parameter ring_hash_dec: forall (r r': RingRuntimeState) (orders: list OrderRuntimeState), *)
(*     (get_ring_hash_preimg r orders = get_ring_hash_preimg r' orders -> *)
(*      ring_hash r orders = ring_hash r' orders) /\ *)
(*     (get_ring_hash_preimg r orders <> get_ring_hash_preimg r' orders -> *)
(*      ring_hash r orders <> ring_hash r' orders). *)
(* Parameter mining_hash: Mining -> list RingRuntimeState -> bytes32. *)
(* Parameter mining_hash_dec: forall (m m': Mining) (rings: list RingRuntimeState), *)
(*     (get_mining_hash_preimg m rings = get_mining_hash_preimg m' rings -> *)
(*      mining_hash m rings = mining_hash m' rings) /\ *)
(*     (get_mining_hash_preimg m rings <> get_mining_hash_preimg m' rings -> *)
(*      mining_hash m rings <> mining_hash m' rings). *)
(* Parameter verify_signature: address -> bytes32 -> bytes -> bool. *)

(* Definition RingSubmitter_step *)
(*            (wst0 wst: WorldState) (msg: RingSubmitterMsg) *)
(*   : (WorldState * RetVal * list Event) := *)
(*   match msg with *)
(*   | msg_submitRings sender orders rings mining => *)
(*     func_submitRings (order_hash := order_hash) *)
(*                      (ring_hash := ring_hash) *)
(*                      (mining_hash := mining_hash) *)
(*                      (verify_signature := verify_signature) *)
(*                      wst0 wst sender orders rings mining *)
(*   end. *)
