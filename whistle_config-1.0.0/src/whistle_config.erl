%%%-------------------------------------------------------------------
%%% @copyright (C) 2011-2016 2600Hz, INC
%%% @doc
%%%
%%% @end
%%% @contributors
%%%-------------------------------------------------------------------
-module(whistle_config).

-include("whistle_config.hrl").

-export([start_link/0
         ,start/0
         ,stop/0
        ]).

%%--------------------------------------------------------------------
%% @public
%% @doc
%% Starts the app for inclusion in a supervisor tree
%% @end
%%--------------------------------------------------------------------
-spec start_link() -> startlink_ret().
start_link() ->
    _ = start_deps(),
    io:format("starting ~s sup", [?MODULE]),
    whistle_config_sup:start_link().

%%--------------------------------------------------------------------
%% @public
%% @doc
%% Starts the application
%% @end
%%--------------------------------------------------------------------
-spec start() -> 'ok' | {'error', any()}.
start() ->
    application:start(?MODULE).

%%--------------------------------------------------------------------
%% @public
%% @doc
%% Stop the app
%% @end
%%--------------------------------------------------------------------
-spec stop() -> 'ok'.
stop() ->
    exit(whereis('whistle_config_sup'), 'shutdown'),
    'ok'.

ini_file() ->
    case os:getenv(?CONFIG_FILE_ENV) of
        'false' -> ?CONFIG_FILE;
        File -> File
    end.

-spec load_file(string()) -> {'ok', wh_proplist()}.
load_file(File) ->
    case zucchini:parse_file(File) of
        {'ok', Prop} ->
            lager:info("loaded configs from file ~s", [File]),
            {'ok', Prop};
        {'error', 'enoent'} ->
            lager:warning("file ~s does not exist or is not accessible", [File]),
            lager:warning("please create ~s or set the environment variable ~s to the path of the config file", [File, ?CONFIG_FILE_ENV]),
            lager:warning("trying defaults instead"),
            {'ok', ?SECTION_DEFAULTS};
        {'error', _}=Error ->
            lager:warning("error loading file ~s: ~s", [File, Error]),
            lager:warning("trying defaults instead"),
            {'ok', ?SECTION_DEFAULTS}
    end.

-spec set_env() -> 'ok'.
set_env() ->
   {'ok', X} = load_file(ini_file()),
    lager:debug("spawning setting of config env for ~p", [X]),
    spawn('application', 'set_env', ['whistle_config', 'wh_config', X]).

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Ensures that all dependencies for this app are already running
%% @end
%%--------------------------------------------------------------------
-spec start_deps() -> 'ok'.
start_deps() ->
    io:format("setting env~n"),
    _Set = set_env(),
    io:format("set ~p~nensuring all started for ~s~n", [_Set, ?MODULE]),
    application:ensure_all_started(?MODULE).
