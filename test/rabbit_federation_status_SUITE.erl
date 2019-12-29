%% The contents of this file are subject to the Mozilla Public License
%% Version 1.1 (the "License"); you may not use this file except in
%% compliance with the License. You may obtain a copy of the License
%% at https://www.mozilla.org/MPL/
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and
%% limitations under the License.
%%
%% The Original Code is RabbitMQ Federation.
%%
%% The Initial Developer of the Original Code is GoPivotal, Inc.
%% Copyright (c) 2007-2020 Pivotal Software, Inc.  All rights reserved.
%%

-module(rabbit_federation_status_SUITE).

-include_lib("common_test/include/ct.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").

-include("rabbit_federation.hrl").

-compile(export_all).

-import(rabbit_federation_test_util,
        [expect/3, expect_empty/2,
         set_upstream/4, clear_upstream/3, set_upstream_set/4,
         set_policy/5, clear_policy/3,
         set_policy_upstream/5, set_policy_upstreams/4,
         no_plugins/1, with_ch/3]).

all() ->
    [
     {group, non_parallel_tests}
    ].

groups() ->
    [
     {non_parallel_tests, [], [
                               exchange_status,
                               queue_status,
                               lookup_exchange_status,
                               lookup_queue_status,
                               lookup_bad_status
                              ]}
    ].

suite() ->
    [{timetrap, {minutes, 5}}].

%% -------------------------------------------------------------------
%% Testsuite setup/teardown.
%% -------------------------------------------------------------------
init_per_suite(Config) ->
    rabbit_ct_helpers:log_environment(),
    Config1 = rabbit_ct_helpers:set_config(Config, [
                                                    {rmq_nodename_suffix, ?MODULE}
                                                   ]),
    rabbit_ct_helpers:run_setup_steps(Config1,
                                      rabbit_ct_broker_helpers:setup_steps() ++
                                          rabbit_ct_client_helpers:setup_steps() ++
                                          [fun rabbit_federation_test_util:setup_federation/1]).
end_per_suite(Config) ->
    rabbit_ct_helpers:run_teardown_steps(Config,
                                         rabbit_ct_client_helpers:teardown_steps() ++
                                             rabbit_ct_broker_helpers:teardown_steps()).

init_per_group(_, Config) ->
    Config.

end_per_group(_, Config) ->
    Config.

init_per_testcase(Testcase, Config) ->
    rabbit_ct_helpers:testcase_started(Config, Testcase).

end_per_testcase(Testcase, Config) ->
    rabbit_ct_helpers:testcase_finished(Config, Testcase).

%% -------------------------------------------------------------------
%% Testcases.
%% -------------------------------------------------------------------
exchange_status(Config) ->
    exchange_SUITE:with_ch(
      Config,
      fun (_Ch) ->
              [Link] = rabbit_ct_broker_helpers:rpc(Config, 0,
                                                    rabbit_federation_status, status, []),
              true = is_binary(proplists:get_value(id, Link))
      end, exchange_SUITE:upstream_downstream()).

queue_status(Config) ->
    with_ch(
      Config,
      fun (_Ch) ->
              [Link] = rabbit_ct_broker_helpers:rpc(Config, 0,
                                                    rabbit_federation_status, status, []),
              true = is_binary(proplists:get_value(id, Link))
      end, queue_SUITE:upstream_downstream()).

lookup_exchange_status(Config) ->
    exchange_SUITE:with_ch(
      Config,
      fun (_Ch) ->
              [Link] = rabbit_ct_broker_helpers:rpc(Config, 0,
                                                    rabbit_federation_status, status, []),
              Id = proplists:get_value(id, Link),
              Props = rabbit_ct_broker_helpers:rpc(Config, 0,
                                                   rabbit_federation_status, lookup, [Id]),
              lists:all(fun(K) -> lists:keymember(K, 1, Props) end,
                        [key, uri, status, timestamp, id, supervisor, upstream])
      end, exchange_SUITE:upstream_downstream()).

lookup_queue_status(Config) ->
    with_ch(
      Config,
      fun (_Ch) ->
              [Link] = rabbit_ct_broker_helpers:rpc(Config, 0,
                                                    rabbit_federation_status, status, []),
              Id = proplists:get_value(id, Link),
              Props = rabbit_ct_broker_helpers:rpc(Config, 0,
                                                   rabbit_federation_status, lookup, [Id]),
              lists:all(fun(K) -> lists:keymember(K, 1, Props) end,
                        [key, uri, status, timestamp, id, supervisor, upstream])
      end, queue_SUITE:upstream_downstream()).

lookup_bad_status(Config) ->
    with_ch(
      Config,
      fun (_Ch) ->
              not_found = rabbit_ct_broker_helpers:rpc(
                            Config, 0,
                            rabbit_federation_status, lookup, [<<"justmadeitup">>])
      end, queue_SUITE:upstream_downstream()).
