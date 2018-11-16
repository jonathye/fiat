Require Import
        Coq.omega.Omega
        Fiat.Narcissus.BinLib
        Fiat.Narcissus.Common.Specs
        Fiat.Narcissus.Common.ComposeOpt
        Fiat.Narcissus.Common.ComposeCheckSum
        Fiat.Narcissus.Common.ComposeIf
        Fiat.Narcissus.Formats
        Fiat.Narcissus.BaseFormats
        Fiat.Narcissus.Automation.Solver
        Fiat.Narcissus.Automation.NormalizeFormats.

Require Import Bedrock.Word.

Ltac start_synthesizing_decoder :=
  match goal with
  | |- CorrectAlignedDecoderFor ?Invariant ?Spec =>
    try unfold Spec (*; try unfold Invariant *)
  end;

  (* Memoize any string constants *)
  (* pose_string_hyps; *)
  eapply Start_CorrectAlignedDecoderFor; simpl; intros.

Ltac align_decoders_step :=
  first [
      eapply @AlignedDecodeNatM; intros
    | eapply @AlignedDecodeBind2CharM; intros; eauto
    | eapply @AlignedDecodeBindCharM; intros; eauto
    | eapply @AlignedDecodeBind3CharM; intros; eauto
    | eapply @AlignedDecodeBind4CharM; intros; eauto
    | eapply @AlignedDecodeBindEnum; intros; eauto
    | let H' := fresh in
      pose proof (fun C D E => @AlignedDecodeBindEnumM _ _ C D E 2) as H';
      simpl in H'; eapply H'; eauto; intros
    | eapply @AlignedDecodeBindUnused2CharM; simpl; eauto;
      eapply DecodeMEquivAlignedDecodeM_trans;
      [ | intros; reflexivity
        |  ]
    | eapply @AlignedDecodeBindUnusedCharM; simpl; eauto;
      eapply DecodeMEquivAlignedDecodeM_trans;
      [ | intros; reflexivity
        |  ]
    | eapply @AlignedDecodeListM; intros; eauto
    | eapply @AlignedDecodeCharM; intros; eauto
    | eapply (fun H H' => @AlignedDecodeNCharM _ _ H H' 4); eauto; simpl; intros
    | eapply (fun H H' => AlignedDecodeNCharM H H'  (m := 2)); eauto; simpl; intros
    | eapply (AlignedDecodeNUnusedCharM _ _ (m := 2)); eauto; simpl; intros
    | eapply @AlignedDecode_shift_if_Sumb
    | eapply @AlignedDecode_shift_if_bool
    | eapply @Return_DecodeMEquivAlignedDecodeM
    | eapply @AlignedDecode_Sumb
    | eapply AlignedDecode_ifopt; intros
    | let H := fresh in pose proof @AlignedDecode_if_Sumb_dep as H;
                        eapply H; clear H;
                        [ solve [eauto] | solve [eauto] | | ]
    | eapply @AlignedDecode_ifb
    | eapply @AlignedDecode_ifb_dep; [ solve [eauto] | solve [eauto] | | ]
    | eapply @AlignedDecodeBindOption; intros; eauto
    | eapply @AlignedDecode_Throw
    | intros; higher_order_reflexivity
    | eapply @AlignedDecode_CollapseEnumWord
    | eapply @AlignedDecode_CollapseWord';
      eauto using decode_word_eq_decode_unused_word,
      decode_word_eq_decode_bool,
      decode_word_eq_decode_nat,
      decode_word_eq_decode_word
    ].

Ltac align_decoders := repeat align_decoders_step.

Ltac synthesize_aligned_decoder :=
  first [ start_synthesizing_decoder;
          [ NormalizeFormats.normalize_format; repeat apply_rules
          |
          |
          | ];
          [ cbv beta; synthesize_cache_invariant
          | cbv beta; unfold decode_nat, Sequence.sequence_Decode; optimize_decoder_impl
          | cbv beta; align_decoders]
        | start_synthesizing_decoder;
          [ NormalizeFormats.normalize_format; repeat apply_rules
          |
          |
          | ] ].

Lemma length_encode_word' sz :
  forall (w : word sz) (b : ByteString),
    bin_measure (encode_word' _ w b) = sz + bin_measure b.
Proof.
  simpl; intros.
  rewrite <- length_encode_word' with (w := w).
  induction sz; intros;
    rewrite (shatter_word w); simpl.
  - reflexivity.
  - reflexivity.
Qed.

Lemma length_ByteString_word
  : forall (sz : nat) (w : word sz) (b : ByteString) (ctx ctx' : CacheFormat),
    format_word w ctx ↝ (b, ctx') -> length_ByteString b = sz.
Proof.
  unfold WordOpt.format_word; simpl.
  intros; computes_to_inv; injections.
  rewrite length_encode_word'; simpl.
  unfold ByteString_id, length_ByteString; simpl; omega.
Qed.

Lemma length_ByteString_unused_word {S}
  : forall (s : S) (sz : nat) (b : ByteString) (ctx ctx' : CacheFormat),
    format_unused_word sz s ctx ↝ (b, ctx') -> length_ByteString b = sz.
Proof.
  unfold format_unused_word, Compose_Format;
    intros; rewrite unfold_computes in H; destruct_ex; split_and.
  unfold format_word in H0; computes_to_inv; injections.
  rewrite length_encode_word'; simpl.
  unfold ByteString_id, length_ByteString; simpl; omega.
Qed.

Lemma length_ByteString_bool
  : forall (b : bool) (bs : ByteString) (ctx ctx' : CacheFormat),
    format_bool b ctx ↝ (bs, ctx') -> length_ByteString bs = 1.
Proof.
  unfold format_bool;
    intros; computes_to_inv; injections.
  reflexivity.
Qed.

Lemma length_ByteString_ret
  : forall (b' b : ByteString) (ctx ctx' : CacheFormat),
    ret (b', ctx) ↝ (b, ctx') -> length_ByteString b = length_ByteString b'.
Proof.
  intros; computes_to_inv; injections; eauto.
Qed.

Lemma length_ByteString_compose:
  forall (format1 format2 : CacheFormat -> Comp (ByteString * CacheFormat))
         (b : ByteString) (ctx ctx' : CacheFormat)
         (n n' : nat),
    (format1 ThenC format2) ctx ↝ (b, ctx') ->
    (forall (ctx0 : CacheFormat) (b0 : ByteString) (ctx'0 : CacheFormat),
        format1 ctx0 ↝ (b0, ctx'0) -> length_ByteString b0 = n) ->
    (forall (ctx0 : CacheFormat) (b0 : ByteString) (ctx'0 : CacheFormat),
        format2 ctx0 ↝ (b0, ctx'0) -> length_ByteString b0 = n') ->
    length_ByteString b = n + n'.
Proof.
  intros.
  unfold compose, Bind2 in H; computes_to_inv.
  destruct v; destruct v0; simpl in *; injections.
  erewrite length_ByteString_enqueue_ByteString, H0, H1; eauto with arith.
Qed.


Ltac eapply_in_hyp lem :=
  match goal with
  | H:_ |- _ => eapply lem in H; [ | clear H | .. | clear H]
  end.

Lemma length_ByteString_map {S S'}
  : forall (sz : nat) (f : S -> S') (format : FormatM S' _) (s : S) (b : ByteString) (ctx ctx' : CacheFormat),
    (format (f s) ctx ∋ (b, ctx') -> length_ByteString b = sz)
    -> Projection_Format format f s ctx ∋ (b, ctx') -> length_ByteString b = sz.
Proof.
  unfold Projection_Format, Compose_Format; intros.
  rewrite unfold_computes in H0; destruct_ex; intuition; subst.
  eapply H; eauto.
Qed.

Corollary length_ByteString_map_word {S}
  : forall (sz : nat) (f : S -> word sz) (s : S) (b : ByteString) (ctx ctx' : CacheFormat),
    Projection_Format format_word f s ctx ∋ (b, ctx') -> length_ByteString b = sz.
Proof.
  intros; eapply length_ByteString_map; eauto using length_ByteString_word.
Qed.

Corollary length_ByteString_map_nat {S}
  : forall (sz : nat) (f : S -> nat) (s : S) (b : ByteString) (ctx ctx' : CacheFormat),
    Projection_Format (format_nat sz) f s ctx ∋ (b, ctx') -> length_ByteString b = sz.
Proof.
  unfold format_nat; intros.
  apply EquivFormat_Projection_Format in H.
  eauto using length_ByteString_word.
Qed.

Corollary length_ByteString_map_bool {S}
  : forall (f : S -> bool) (s : S) (b : ByteString) (ctx ctx' : CacheFormat),
    Projection_Format format_bool f s ctx ∋ (b, ctx') -> length_ByteString b = 1.
Proof.
  intros; eapply length_ByteString_map; eauto using length_ByteString_bool.
Qed.

Lemma length_ByteString_map_option {S S'}
  : forall (sz : nat) (f : S -> option S')
           (format_Some : FormatM S' _)
           (format_None : FormatM () _)
           (s : S) (b : ByteString) (ctx ctx' : CacheFormat),
    (forall s', format_Some s' ctx ∋ (b, ctx') -> length_ByteString b = sz)
    -> (format_None () ctx ∋ (b, ctx') -> length_ByteString b = sz)
    -> Projection_Format (Option.format_option format_Some format_None) f s ctx ∋ (b, ctx') -> length_ByteString b = sz.
Proof.
  unfold Projection_Format, Compose_Format; intros.
  rewrite unfold_computes in H1; destruct_ex; intuition; subst.
  destruct (f s); simpl in *; eauto.
Qed.

Corollary length_ByteString_map_enum {S'}
  : forall (len sz : nat)
           (codes : Vector.t (word sz) (S len))
           (f : S' -> Fin.t (S len)) (s : S') (b : ByteString) (ctx ctx' : CacheFormat),
    Projection_Format (format_enum codes) f s ctx ∋ (b, ctx') -> length_ByteString b = sz.
Proof.
  intros; eapply length_ByteString_map; eauto.
  eauto using length_ByteString_word.
Qed.

Ltac calculate_length_ByteString' :=
  repeat first [ apply_in_hyp @length_ByteString_map_word
               | apply_in_hyp @length_ByteString_map_bool
               | apply_in_hyp @length_ByteString_word
               | apply_in_hyp @length_ByteString_unused_word
               | apply_in_hyp @length_ByteString_bool
               | eapply_in_hyp @length_ByteString_map_option;
                 [ | clear; intros | .. | clear; intros ]
               | apply_in_hyp @length_ByteString_map_nat
               | apply_in_hyp @length_ByteString_map_enum
               | eapply_in_hyp @length_ByteString_compose;
                 [ | clear; intros | .. | clear; intros ]
               | eassumption].

Ltac associate_for_ByteAlignment :=
  eapply @Guarded_CorrectAlignedEncoderThenCAssoc;
  [clear; intros ce bs ce' Comp ? ;
   calculate_length_ByteString'; omega
  | ].

(*Lemma CorrectAlignedEncoderForFormatOption {S}
     : forall (format_Some : FormatM S ByteString) (encode_A : forall sz : nat, AlignedEncodeM sz),
       CorrectAlignedEncoder format_A encode_A ->
       CorrectAlignedEncoder (format_list format_A) (AlignedEncodeList encode_A)

Lemma
  CorrectAlignedEncoder
    (Option.format_option format_word (format_unused_word 16) ◦ UrgentPointer ++
     format_list format_word ◦ Options ++ format_list format_word ◦ Payload) ?encode_A *)

(*Lemma CollapseCorrectAlignedEncoderFormatWord
      (addE_addE_plus :
         forall ce n m, addE (addE ce n) m = addE ce (n + m))
  : forall sz {sz'} (w' : word sz') k encoder,
    CorrectAlignedEncoder
      ((format_word (combine w' (wzero sz)))
         ThenC k)
      encoder
    -> CorrectAlignedEncoder
         ((format_unused_word sz)
            ThenC (format_word w')
            ThenC k)
         encoder.
Proof.
  intros; eapply refine_CorrectAlignedEncoder; eauto.
  intros; rewrite <- CollapseFormatWord; eauto.
  unfold compose, Bind2; f_equiv.
  unfold format_unused_word, format_unused_word'.
  repeat computes_to_econstructor; eauto.
Qed. *)

Lemma refine_format_unused_word {S}
  : forall sz (s : S) ce,
    refine (format_unused_word sz s ce) (format_word (wzero sz) ce).
Proof.
  intros; unfold format_unused_word, Compose_Format;
    intros ? ?.
  apply unfold_computes; eexists; split; eauto.
  apply unfold_computes; eauto.
Qed.

Lemma refine_format_bool
  : forall b ce,
    refine (format_bool b ce) (format_word (WS b WO) ce).
Proof.
  intros; unfold format_bool.
  reflexivity.
Qed.

Lemma refine_format_bool_map {S}
      (f : S -> bool)
  : forall s ce,
    refine (FMapFormat.Projection_Format format_bool f s ce) (FMapFormat.Projection_Format format_word (fun s => (WS (f s) WO)) s ce).
Proof.
  intros; unfold FMapFormat.Projection_Format, FMapFormat.Compose_Format; intros ? ?.
  rewrite unfold_computes in H; destruct_ex; intuition.
  apply unfold_computes; eexists; split; eauto; subst.
  eapply refine_format_bool; eauto.
Qed.

Lemma refine_format_option sz {S}
      (Some_format : FormatM S _)
      (None_format : FormatM () _)
      (f : S -> word sz)
      (f' : word sz)
      (refine_Some : forall (s : S) (env : CacheFormat), refine (Some_format s env) ((format_word ◦ f) s env))
      (refine_None : forall (env : CacheFormat), refine (None_format () env) ((format_word ◦ (fun _ => f')) () env))
  : forall (s : option S) ce,
    refine (Option.format_option Some_format None_format s ce)
           ((format_word ◦ (fun s => Ifopt s as s' Then f s' Else f')) s ce).
Proof.
  intros; destruct s; simpl; eauto.
  eapply refine_Some.
Qed.

Lemma refine_format_option_map sz {S S'}
      (g : S' -> option S)
      (Some_format : FormatM S _)
      (None_format : FormatM () _)
      (f : S -> word sz)
      (f' : word sz)
      (refine_Some : forall (s : S) (env : CacheFormat), refine (Some_format s env) ((format_word ◦ f) s env))
      (refine_None : forall (env : CacheFormat), refine (None_format () env) ((format_word ◦ (fun _ => f')) () env))
  : forall s ce,
    refine (FMapFormat.Projection_Format (Option.format_option Some_format None_format) g s ce)
           (FMapFormat.Projection_Format format_word
                                         ((fun s => Ifopt (g s) as s' Then f s' Else f')) s ce).
Proof.
  intros; unfold FMapFormat.Projection_Format, FMapFormat.Compose_Format; intros ? ?.
  rewrite unfold_computes in H; destruct_ex; intuition.
  apply unfold_computes; eexists; split; eauto; subst.
  eapply refine_format_option; eauto.
  apply EquivFormat_Projection_Format in H0; eauto.
Qed.

Lemma refine_format_nat_map {S}
      {sz}
      (f : S -> nat)
  : forall s ce,
    refine (FMapFormat.Projection_Format (format_nat sz) f s ce)
           (FMapFormat.Projection_Format format_word (Basics.compose (natToWord sz) f) s ce).
Proof.
  intros; unfold FMapFormat.Projection_Format, FMapFormat.Compose_Format, format_nat; intros ? ?.
  rewrite unfold_computes in H; destruct_ex; intuition.
  apply unfold_computes; eexists; split; eauto; subst.
  eauto.
Qed.

Lemma refine_format_enum_map {S}
      {sz sz'}
      (f : S -> Fin.t (1 + sz'))
      (tb : Vector.t (word sz) _)
  : forall s ce,
    refine (FMapFormat.Projection_Format (format_enum tb) f s ce)
           (FMapFormat.Projection_Format format_word (Basics.compose (Vector.nth tb) f) s ce).
Proof.
  intros; unfold FMapFormat.Projection_Format, FMapFormat.Compose_Format, format_enum; intros ? ?.
  rewrite unfold_computes in H; destruct_ex; intuition.
  apply unfold_computes; eexists; split; eauto; subst.
  eauto.
Qed.

Lemma refine_format_unused_word_map {S}
  : forall sz (s : S) ce,
    refine (format_unused_word sz s ce) (FMapFormat.Projection_Format format_word (fun s => wzero sz) s ce).
Proof.
  unfold format_unused_word, FMapFormat.Projection_Format, Compose_Format; intros;
    intros ? ?.
  rewrite unfold_computes in H; destruct_ex; intuition; subst.
  apply unfold_computes; eexists; split; eauto.
  apply unfold_computes; eauto.
Qed.

Lemma refine_format_word_map {S}
      {sz}
      (f : S -> word sz)
  : forall s ce,
    refine (FMapFormat.Projection_Format format_word f s ce) (format_word (f s) ce).
Proof.
  intros; unfold FMapFormat.Projection_Format, FMapFormat.Compose_Format; intros ? ?.
  apply unfold_computes; eexists; split; eauto.
Qed.

  Lemma length_ByteString_Projection {S S'}:
    forall (format1 : FormatM S ByteString)
           (f : S' -> S)
           (b : ByteString) s (ctx ctx' : CacheFormat)
           (n : nat),
      (Projection_Format format1 f)%format s ctx ↝ (b, ctx') ->
      (forall (ctx0 : CacheFormat) (b0 : ByteString) (ctx'0 : CacheFormat),
          format1 (f s) ctx0 ↝ (b0, ctx'0) -> length_ByteString b0 = n) ->
      length_ByteString b = n.
  Proof.
    intros.
    eapply H0.
    eapply EquivFormat_Projection_Format; eauto.
  Qed.

  Ltac calculate_length_ByteString :=
  intros;
  match goal with
  | H:_ ↝ _
    |- _ =>
    (first
       [ eapply (length_ByteString_composeChecksum _ _ _ _ _ _ _ H);
         try (simpl mempty; rewrite length_ByteString_ByteString_id)
       | eapply (length_ByteString_composeIf _ _ _ _ _ _ _ H);
         try (simpl mempty; rewrite length_ByteString_ByteString_id)
       | eapply (length_ByteString_compose _ _ _ _ _ _ _ H);
         try (simpl mempty; rewrite length_ByteString_ByteString_id)
       | eapply (length_ByteString_Projection _ _ _ _ _ _ _ H)
       | eapply (fun H' H'' => length_ByteString_format_option _ _ _ _ _ _ _ H' H'' H)
       | eapply (length_ByteString_unused_word _ _ _ _ _ H)
       | eapply (length_ByteString_bool _ _ _ _ H)
       | eapply (length_ByteString_word _ _ _ _ _ H)
       | eapply (fun H' => length_ByteString_format_list _ _ _ _ _ _ H' H)
       | eapply (length_ByteString_ret _ _ _ _ H) ]);
    clear H
  end.

  Ltac collapse_unaligned_words :=
    intros; eapply refine_CorrectAlignedEncoder;
    [repeat (eauto ; intros; eapply refine_CollapseFormatWord'; eauto);
     unfold format_nat;
     repeat first [eapply refine_format_option_map; intros
                  | eapply refine_format_bool_map
                  | eauto using refine_format_bool, refine_format_unused_word_map,
                    refine_format_bool_map, refine_format_unused_word,
                    refine_format_option_map, refine_format_enum_map,
                    refine_format_nat_map];
     reflexivity
    | ].

Ltac start_synthesizing_encoder :=
  lazymatch goal with
  | |- CorrectAlignedEncoderFor ?Spec =>
    try unfold Spec
  end;
  (* Memoize any string constants *)
  (*pose_string_hyps; *)
  eexists; simpl; intros.

Ltac align_encoder_step :=
  first
    [ match goal with
        |- CorrectAlignedEncoder (_ ThenChecksum _ OfSize _ ThenCarryOn _) _ =>
        eapply @CorrectAlignedEncoderForIPChecksumThenC
      end
    | match goal with
        |- CorrectAlignedEncoder (_ ++ _ ++ _)%format _ => associate_for_ByteAlignment
      end
    | match goal with
        |- CorrectAlignedEncoder (_ ++ _)%format  _ =>
        apply @CorrectAlignedEncoderForThenC;
        [ | try collapse_unaligned_words ]
      end
    | match goal with
        |- CorrectAlignedEncoder (Either _ Or _)%format _ =>
        eapply CorrectAlignedEncoderEither_E
      end
    | apply CorrectAlignedEncoderForFormatList
    | apply CorrectAlignedEncoderForFormatVector;
      [ solve [ eauto ]
      | solve [ eauto ]
      | ]
    | apply CorrectAlignedEncoderForFormatChar; eauto
    | apply CorrectAlignedEncoderForFormatNat
    | apply CorrectAlignedEncoderForFormatEnum
    | eapply CorrectAlignedEncoderProjection
    | eapply (fun H H' => CorrectAlignedEncoderForFormatNEnum H H' 2);
      [ solve [ eauto ]
      | solve [ eauto ] ]
    | eapply (fun H H' => CorrectAlignedEncoderForFormatNEnum H H' 3);
      [ solve [ eauto ]
      | solve [ eauto ] ]
    | eapply CorrectAlignedEncoderForFormatUnusedWord
    | eapply CorrectAlignedEncoderForFormatOption
    | intros; eapply CorrectAlignedEncoderForFormatNChar with (sz := 2); eauto
    | intros; eapply CorrectAlignedEncoderForFormatNChar with (sz := 3); eauto
    | intros; eapply CorrectAlignedEncoderForFormatNChar with (sz := 4); eauto
    | intros; eapply CorrectAlignedEncoderForFormatNChar with (sz := 5); eauto].

Ltac synthesize_aligned_encoder :=
  start_synthesizing_encoder;
  repeat align_encoder_step.
