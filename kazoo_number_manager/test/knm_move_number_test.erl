%%%-------------------------------------------------------------------
%%% @copyright (C) 2015-2017, 2600Hz
%%% @doc
%%% @end
%%% @contributors
%%%   James Aimonetti
%%%   Pierre Fenoll
%%%-------------------------------------------------------------------
-module(knm_move_number_test).

-include_lib("eunit/include/eunit.hrl").
-include("knm.hrl").

move_to_child_test_() ->
    {'ok', N} = knm_number:move(?TEST_AVAILABLE_NUM, ?CHILD_ACCOUNT_ID),
    PN = knm_number:phone_number(N),
    [?_assert(knm_phone_number:is_dirty(PN))
    ,{"verify assigned_to is child account"
     ,?_assertEqual(?CHILD_ACCOUNT_ID, knm_phone_number:assigned_to(PN))
     }
    ].

move_changing_public_fields_test_() ->
    Key = <<"my_key">>,
    Fields = [{<<"a">>, <<"bla">>}
             ,{Key, 42}
             ],
    Options = [{public_fields, kz_json:from_list(Fields)}
               |knm_number_options:default()
              ],
    {ok, N0} = knm_number:get(?TEST_AVAILABLE_NUM),
    {ok, N} = knm_number:move(?TEST_AVAILABLE_NUM, ?RESELLER_ACCOUNT_ID, Options),
    [?_assert(knm_phone_number:is_dirty(knm_number:phone_number(N)))
    ,{"verify a public key is set"
     ,?_assertEqual(<<"my string">>, public_value(Key, N0))
     }
    ,{"verify that key got updated"
     ,?_assertEqual(42, public_value(Key, N))
     }
    ,{"verify another key was added"
     ,?_assertEqual(<<"bla">>, public_value(<<"a">>, N))
     }
    ,{"verify that that other key is really new"
     ,?_assertEqual(undefined, public_value(<<"a">>, N0))
     }
    ].

public_value(Key, N) ->
    kz_json:get_value(Key, knm_number:to_public_json(N)).


move_available_local_test_() ->
    {ok, N0} = knm_number:get(?TEST_AVAILABLE_NUM),
    PN0 = knm_number:phone_number(N0),
    [?_assert(not knm_phone_number:is_dirty(PN0))
    ,{"Verify number is available"
     ,?_assertEqual(?NUMBER_STATE_AVAILABLE, knm_phone_number:state(PN0))
     }
    ,{"Verify an available number is unassgined"
     ,?_assertEqual(undefined, knm_phone_number:assigned_to(PN0))
     }
    ,?_assertEqual(?RESELLER_ACCOUNT_ID, knm_phone_number:prev_assigned_to(PN0))
    ,?_assertEqual([], knm_phone_number:reserve_history(PN0))
    ,?_assertEqual(?CARRIER_LOCAL, knm_phone_number:module_name(PN0))
    ,?_assertEqual([?FEATURE_LOCAL], knm_phone_number:features_list(PN0))
    ]
        ++ everyone_is_allowed_to_buy_local_available(?CHILD_ACCOUNT_ID, ?CHILD_ACCOUNT_ID)
        ++ everyone_is_allowed_to_buy_local_available(?CHILD_ACCOUNT_ID, ?RESELLER_ACCOUNT_ID)
        ++ everyone_is_allowed_to_buy_local_available(?CHILD_ACCOUNT_ID, ?MASTER_ACCOUNT_ID)

        ++ everyone_is_allowed_to_buy_local_available(?RESELLER_ACCOUNT_ID, ?CHILD_ACCOUNT_ID)
        ++ everyone_is_allowed_to_buy_local_available(?RESELLER_ACCOUNT_ID, ?RESELLER_ACCOUNT_ID)
        ++ everyone_is_allowed_to_buy_local_available(?RESELLER_ACCOUNT_ID, ?MASTER_ACCOUNT_ID)

        ++ everyone_is_allowed_to_buy_local_available(?MASTER_ACCOUNT_ID, ?CHILD_ACCOUNT_ID)
        ++ everyone_is_allowed_to_buy_local_available(?MASTER_ACCOUNT_ID, ?RESELLER_ACCOUNT_ID)
        ++ everyone_is_allowed_to_buy_local_available(?MASTER_ACCOUNT_ID, ?MASTER_ACCOUNT_ID)
        ++ [].

move_available_non_local_test_() ->
    {ok, N0} = knm_number:get(?TEST_AVAILABLE_NON_LOCAL_NUM),
    PN0 = knm_number:phone_number(N0),
    [?_assert(not knm_phone_number:is_dirty(PN0))
    ,{"Verify number is available"
     ,?_assertEqual(?NUMBER_STATE_AVAILABLE, knm_phone_number:state(PN0))
     }
    ,{"Verify an available number is unassgined"
     ,?_assertEqual(undefined, knm_phone_number:assigned_to(PN0))
     }
    ,?_assertEqual(?RESELLER_ACCOUNT_ID, knm_phone_number:prev_assigned_to(PN0))
    ,?_assertEqual([], knm_phone_number:reserve_history(PN0))
    ,?_assertEqual(<<"knm_telnyx">>, knm_phone_number:module_name(PN0))
    ,?_assertEqual([], knm_phone_number:features_list(PN0))
    ]
        ++ everyone_is_allowed_to_buy_available(?CHILD_ACCOUNT_ID, ?CHILD_ACCOUNT_ID)
        ++ everyone_is_allowed_to_buy_available(?CHILD_ACCOUNT_ID, ?RESELLER_ACCOUNT_ID)
        ++ everyone_is_allowed_to_buy_available(?CHILD_ACCOUNT_ID, ?MASTER_ACCOUNT_ID)

        ++ everyone_is_allowed_to_buy_available(?RESELLER_ACCOUNT_ID, ?CHILD_ACCOUNT_ID)
        ++ everyone_is_allowed_to_buy_available(?RESELLER_ACCOUNT_ID, ?RESELLER_ACCOUNT_ID)
        ++ everyone_is_allowed_to_buy_available(?RESELLER_ACCOUNT_ID, ?MASTER_ACCOUNT_ID)

        ++ everyone_is_allowed_to_buy_available(?MASTER_ACCOUNT_ID, ?CHILD_ACCOUNT_ID)
        ++ everyone_is_allowed_to_buy_available(?MASTER_ACCOUNT_ID, ?RESELLER_ACCOUNT_ID)
        ++ everyone_is_allowed_to_buy_available(?MASTER_ACCOUNT_ID, ?MASTER_ACCOUNT_ID)
        ++ [].

everyone_is_allowed_to_buy_local_available(AuthBy, AssignTo) ->
    Num = ?TEST_AVAILABLE_NUM,
    everyone_is_allowed_to_buy_available(Num, AuthBy, AssignTo, ?CARRIER_LOCAL, [?FEATURE_LOCAL]).
everyone_is_allowed_to_buy_available(AuthBy, AssignTo) ->
    Num = ?TEST_AVAILABLE_NON_LOCAL_NUM,
    everyone_is_allowed_to_buy_available(Num, AuthBy, AssignTo, <<"knm_telnyx">>, []).

everyone_is_allowed_to_buy_available(Num, AuthBy, AssignTo, Carrier, Features) ->
    {ok, N} = knm_number:move(Num, AssignTo, [{auth_by,AuthBy}]),
    PN = knm_number:phone_number(N),
    [?_assert(knm_phone_number:is_dirty(PN))
    ,?_assertEqual(Num, knm_phone_number:number(PN))
    ,{"Verify number is now in_service" ++ auth_and_assign(AuthBy, AssignTo)
     ,?_assertEqual(?NUMBER_STATE_IN_SERVICE, knm_phone_number:state(PN))
     }
    ,{"Verify number is now assigned" ++ auth_and_assign(AuthBy, AssignTo)
     ,?_assertEqual(AssignTo, knm_phone_number:assigned_to(PN))
     }
    ,?_assertEqual(?RESELLER_ACCOUNT_ID, knm_phone_number:prev_assigned_to(PN))
    ,?_assertEqual([], knm_phone_number:reserve_history(PN))
    ,?_assertEqual(Carrier, knm_phone_number:module_name(PN))
    ,?_assertEqual(Features, knm_phone_number:features_list(PN))
    ].

auth_and_assign(AuthBy, AssignTo) ->
    lists:flatten(
      [", auth_by/assign_to: "
      ,binary_to_list(binary:part(AuthBy, 0, 8))
      ,$/
      ,binary_to_list(binary:part(AssignTo, 0, 8))
      ]).
