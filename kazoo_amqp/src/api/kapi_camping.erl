%%%-------------------------------------------------------------------
%%% @copyright (C) 2011-2017, 2600Hz INC
%%% @doc
%%% Routing requests, responses, and wins!
%%% @end
%%% @contributors
%%%   James Aimonetti
%%%   Karl Anderson
%%%-------------------------------------------------------------------
-module(kapi_camping).

-export([req/1, req_v/1
        ,bind_q/2, unbind_q/2
        ,declare_exchanges/0
        ,publish_req/1, publish_req/2
        ]).

-include_lib("amqp_util.hrl").

-type req() :: api_terms().

-export_type([req/0]).

-define(REQ_ROUTING_KEY(AccountId), <<"camping.request.", (AccountId)/binary>>).
-define(REQ_HEADERS, [<<"Camping-Request">>, <<"Account-ID">>]).
-define(OPTIONAL_REQ_HEADERS, []).
-define(REQ_VALUES, [{<<"Event-Category">>, <<"camping">>}
                    ,{<<"Event-Name">>, <<"request">>}
                    ]).
-define(REQ_TYPES, [{<<"Camping-Request">>, fun kz_json:is_json_object/1}]).

-spec req(api_terms()) ->
                 {'ok', iolist()} |
                 {'error', string()}.
req(Prop) when is_list(Prop) ->
    case req_v(Prop) of
        'true' -> kz_api:build_message(Prop, ?REQ_HEADERS, ?OPTIONAL_REQ_HEADERS);
        'false' -> {'error', "Proplist failed validation for _req"}
    end;
req(JObj) -> req(kz_json:to_proplist(JObj)).

-spec req_v(api_terms()) -> boolean().
req_v(Prop) when is_list(Prop) ->
    kz_api:validate(Prop, ?REQ_HEADERS, ?REQ_VALUES, ?REQ_TYPES);
req_v(JObj) -> req_v(kz_json:to_proplist(JObj)).

-spec bind_q(ne_binary(), kz_proplist() | ne_binary()) -> 'ok'.
bind_q(Queue, Props) when is_list(Props) ->
    bind_q(Queue, props:get_value('account_id', Props, <<"*">>));
bind_q(Queue, ?NE_BINARY=AccountId) ->
    amqp_util:bind_q_to_callmgr(Queue, ?REQ_ROUTING_KEY(AccountId)).

-spec unbind_q(ne_binary(), kz_proplist() | ne_binary()) -> 'ok'.
unbind_q(Queue, Props) when is_list(Props) ->
    bind_q(Queue, props:get_value('account_id', Props, <<"*">>));
unbind_q(Queue, ?NE_BINARY=AccountId) ->
    amqp_util:unbind_q_from_callmgr(Queue, ?REQ_ROUTING_KEY(AccountId)).

-spec declare_exchanges() -> 'ok'.
declare_exchanges() ->
    amqp_util:callmgr_exchange().

-spec publish_req(api_terms()) -> 'ok'.
-spec publish_req(api_terms(), binary()) -> 'ok'.
publish_req(JObj) ->
    publish_req(JObj, ?DEFAULT_CONTENT_TYPE).
publish_req(Req, ContentType) ->
    {'ok', Payload} = kz_api:prepare_api_payload(Req, ?REQ_VALUES, fun req/1),
    amqp_util:callmgr_publish(Payload, ContentType, ?REQ_ROUTING_KEY(get_account_id(Req))).

-spec get_account_id(api_terms()) -> ne_binary().
get_account_id(Props) when is_list(Props) ->
    props:get_value(<<"Account-ID">>, Props);
get_account_id(JObj) ->
    kz_json:get_value(<<"Account-ID">>, JObj).
