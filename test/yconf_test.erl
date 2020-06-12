%%%-------------------------------------------------------------------
%%% Created : 26 Sep 2018 by Evgeny Khramtsov <ekhramtsov@process-one.net>
%%%
%%% Copyright (C) 2002-2020 ProcessOne, SARL. All Rights Reserved.
%%%
%%% Licensed under the Apache License, Version 2.0 (the "License");
%%% you may not use this file except in compliance with the License.
%%% You may obtain a copy of the License at
%%%
%%%     http://www.apache.org/licenses/LICENSE-2.0
%%%
%%% Unless required by applicable law or agreed to in writing, software
%%% distributed under the License is distributed on an "AS IS" BASIS,
%%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%% See the License for the specific language governing permissions and
%%% limitations under the License.
%%%
%%%-------------------------------------------------------------------
-module(yconf_test).
-include_lib("eunit/include/eunit.hrl").

-define(checkError(Pattern, Expression),
	(fun() ->
		 Ret = Expression,
		 ?assertMatch({error, Pattern, _}, Ret),
		 test_format_error(Ret)
	 end)()).

%%%===================================================================
%%% Tests
%%%===================================================================
start_test() ->
    ?assertEqual(ok, yconf:start()).

validate_test() ->
    ?assertEqual({ok, 1}, yconf:validate(yconf:any(), 1)).

error_validate_test() ->
    ?checkError(
       {bad_int, _},
       yconf:validate(yconf:int(), foo)).

empty_yaml_test() ->
    File = file(""),
    ?assertEqual({ok, []}, yconf:parse(File, #{})).

bad_yaml_test() ->
    ?checkError(
       {bad_yaml, enoent, _},
       yconf:parse("non-existent.yml", #{})).

define_macro_test() ->
    File = file(["define_macro:",
		 "  A: 1",
		 "  B: 2",
		 "  C: 3",
		 "a: A",
		 "b: B",
		 "c: C"]),
    ?assertEqual(
       {ok, [{a, 1}, {b, 2}, {c, 3}]},
       yconf:parse(File, #{'_' => yconf:any()}, [replace_macros])).

include_config_file_test() ->
    IncludedFile = included_file(["a: 1",
				  "b: 2"]),
    File = file(["include_config_file: " ++ IncludedFile,
		 "c: 3"]),
    ?assertEqual(
       {ok, [{a, 1}, {b, 2}, {c, 3}]},
       yconf:parse(File, #{'_' => yconf:any()}, [include_files])).

include_allow_only_test() ->
    IncludedFile = included_file(["a: 1",
				  "b: 2",
				  "c: 3"]),
    File = file(["include_config_file:",
		 " " ++ IncludedFile  ++ ":",
		 "  allow_only:",
		 "   - a",
		 "   - c"]),
    ?assertEqual(
       {ok, [{a, 1}, {c, 3}]},
       yconf:parse(File, #{'_' => yconf:any()}, [include_files])).

include_disallow_test() ->
    IncludedFile = included_file(["a: 1",
				  "b: 2",
				  "c: 3"]),
    File = file(["include_config_file:",
		 " " ++ IncludedFile  ++ ":",
		 "  disallow:",
		 "   - a",
		 "   - c"]),
    ?assertEqual(
       {ok, [{b, 2}]},
       yconf:parse(File, #{'_' => yconf:any()}, [include_files])).

duplicated_macro_test() ->
    File = file(["define_macro:",
		 " MACRO: 1",
		 "define_macro:",
		 " MACRO: 2",
		 "a: MACRO"]),
    ?checkError(
       {duplicated_macro, <<"MACRO">>},
       yconf:parse(File, #{'_' => yconf:any()}, [replace_macros])).

included_macro_test() ->
    IncludedFile = included_file(["define_macro:",
				  " MACRO: 1",
				  "b: MACRO"]),
    File = file(["a: MACRO",
		 "include_config_file: " ++ IncludedFile]),
    ?assertEqual(
       {ok, [{a, 1}, {b, 1}]},
       yconf:parse(File, #{'_' => yconf:any()}, [replace_macros, include_files])).

nested_macro_test() ->
    File = file(["define_macro:",
		 " FOO: BAR",
		 " BAR: BAZ",
		 " BAZ: baz",
		 "foo: FOO",
		 "bar: FOO",
		 "baz: FOO"]),
    ?assertEqual(
       {ok, [{foo, <<"baz">>}, {bar, <<"baz">>}, {baz, <<"baz">>}]},
       yconf:parse(File, #{'_' => yconf:any()}, [replace_macros])).

include_circular_test() ->
    File = file(""),
    IncludedFile = included_file(["include_config_file: " ++ File]),
    File = file(["include_config_file: " ++ IncludedFile]),
    ?checkError(
       {bad_yaml, circular_include, _},
       yconf:parse(File, #{}, [include_files])).

macro_circular_test() ->
    File = file(["define_macro:",
		 " FOO: BAR",
		 " BAR: BAZ",
		 " BAZ: FOO"]),
    ?checkError(
       {circular_macro, <<"FOO">>},
       yconf:parse(File, #{}, [replace_macros])).

any_test() ->
    File = file(["a: 1"]),
    ?assertEqual(
       {ok, [{a, 1}]},
       yconf:parse(File, #{a => yconf:any()})).

enum_atom_test() ->
    File = file(["a: foo"]),
    ?assertEqual(
       {ok, [{a, foo}]},
       yconf:parse(File, #{a => yconf:enum([foo, bar])})).

enum_binary_test() ->
    File = file(["a: foo"]),
    ?assertEqual(
       {ok, [{a, <<"foo">>}]},
       yconf:parse(File, #{a => yconf:enum([<<"foo">>, <<"bar">>])})).

bad_enum_test() ->
    File = file(["a: baz"]),
    ?checkError(
       {bad_enum, [foo, bar], baz},
       yconf:parse(File, #{a => yconf:enum([foo, bar])})).

bool_test() ->
    File = file(["a: true",
		 "b: false",
		 "c: on",
		 "d: off",
		 "e: yes",
		 "f: no",
		 "g: y",
		 "h: n"]),
    ?assertEqual(
       {ok, [{a, true}, {b, false}, {c, true}, {d, false},
	     {e, true}, {f, false}, {g, true}, {h, false}]},
       yconf:parse(File, #{a => yconf:bool(),
			   b => yconf:bool(),
			   c => yconf:bool(),
			   d => yconf:bool(),
			   e => yconf:bool(),
			   f => yconf:bool(),
			   g => yconf:bool(),
			   h => yconf:bool()})).

bad_bool_test() ->
    File = file(["a: bad"]),
    ?checkError(
       {bad_bool, bad},
       yconf:parse(File, #{a => yconf:bool()})).

int_test() ->
    File = file(["a: 5",
		 "b: 0",
		 "c: -7"]),
    ?assertEqual(
       {ok, [{a, 5}, {b, 0}, {c, -7}]},
       yconf:parse(File, #{a => yconf:int(),
			   b => yconf:int(),
			   c => yconf:int()})).

bad_int_test() ->
    File = file(["a: bad"]),
    ?checkError(
       {bad_int, _},
       yconf:parse(File, #{a => yconf:int()})).

int_range_test() ->
    File = file(["a: 5",
		 "b: 0",
		 "c: -10"]),
    ?assertEqual(
       {ok, [{a, 5}, {b, 0}, {c, -10}]},
       yconf:parse(File, #{a => yconf:int(4, 5),
			   b => yconf:int(-1, 5),
			   c => yconf:int(-10, 0)})).

bad_int_range_test() ->
    File = file(["a: 5"]),
    ?checkError(
       {bad_int, 10, 20, 5},
       yconf:parse(File, #{a => yconf:int(10, 20)})).

pos_int_test() ->
    File = file(["a: 1"]),
    ?assertEqual(
       {ok, [{a, 1}]},
       yconf:parse(File, #{a => yconf:pos_int()})).

bad_pos_int_test() ->
    File = file(["a: 0"]),
    ?checkError(
       {bad_pos_int, 0},
       yconf:parse(File, #{a => yconf:pos_int()})).

pos_int_infinity_test() ->
    File = file(["a: 1",
		 "b: infinity",
		 "c: infinite",
		 "d: unlimited"]),
    ?assertEqual(
       {ok, [{a, 1}, {b, infinite}, {c, unlimited}, {d, infinity}]},
       yconf:parse(File, #{a => yconf:pos_int(infinity),
			   b => yconf:pos_int(infinite),
			   c => yconf:pos_int(unlimited),
			   d => yconf:pos_int(infinity)})).

bad_pos_int_infinity_test() ->
    File = file(["a: 0"]),
    ?checkError(
       {bad_pos_int, infinity, 0},
       yconf:parse(File, #{a => yconf:pos_int(infinity)})),
    ?checkError(
       {bad_int, foo},
       yconf:validate(yconf:pos_int(infinity), foo)),
    ?checkError(
       {bad_int, _},
       yconf:validate(
	 yconf:pos_int(infinity),
	 list_to_binary(lists:duplicate(256, $z)))).

non_neg_int_test() ->
    File = file(["a: 0"]),
    ?assertEqual(
       {ok, [{a, 0}]},
       yconf:parse(File, #{a => yconf:non_neg_int()})).

bad_non_neg_int_test() ->
    File = file(["a: -1"]),
    ?checkError(
       {bad_non_neg_int, -1},
       yconf:parse(File, #{a => yconf:non_neg_int()})).

non_neg_int_infinity_test() ->
    File = file(["a: 0",
		 "b: infinity",
		 "c: infinite",
		 "d: unlimited"]),
    ?assertEqual(
       {ok, [{a, 0}, {b, infinite}, {c, unlimited}, {d, infinity}]},
       yconf:parse(File, #{a => yconf:non_neg_int(infinity),
			   b => yconf:non_neg_int(infinite),
			   c => yconf:non_neg_int(unlimited),
			   d => yconf:non_neg_int(infinity)})).

bad_non_neg_int_infinity_test() ->
    File = file(["a: -1"]),
    ?checkError(
       {bad_non_neg_int, infinity, -1},
       yconf:parse(File, #{a => yconf:non_neg_int(infinity)})).

number_test() ->
    File = file(["a: 0.5"]),
    ?assertEqual(
       {ok, [{a, 0.5}]},
       yconf:parse(File, #{a => yconf:number(0.5)})).

bad_number_test() ->
    File = file(["a: bad"]),
    ?checkError(
       {bad_number, _},
       yconf:parse(File, #{a => yconf:number(1.0)})),
    File = file(["a: 0.4"]),
    ?checkError(
       {bad_number, 0.5, 0.4},
       yconf:parse(File, #{a => yconf:number(0.5)})).

binary_test() ->
    File = file(["a: foo",
		 "b: \"bar\"",
		 "c: 'baz'"]),
    ?assertEqual(
       {ok, [{a, <<"foo">>}, {b, <<"bar">>}, {c, <<"baz">>}]},
       yconf:parse(File, #{a => yconf:binary(),
			   b => yconf:binary(),
			   c => yconf:binary()})),
    ?assertEqual(<<"foo">>, (yconf:binary())(foo)).

bad_binary_test() ->
    File = file(["a: 1"]),
    ?checkError(
       {bad_binary, 1},
       yconf:parse(File, #{a => yconf:binary()})).

binary_re_test() ->
    File = file(["a: foo",
		 "b: BAR",
		 "c: \"123\""]),
    ?assertEqual(
       {ok, [{a, <<"foo">>}, {b, <<"BAR">>}, {c, <<"123">>}]},
       yconf:parse(File, #{a => yconf:binary("^[a-z]+$"),
			   b => yconf:binary("^[A-Z]+$"),
			   c => yconf:binary("^[0-9]+$")})).

bad_binary_re_test() ->
    File = file(["a: fooBAR"]),
    ?checkError(
       {nomatch, "^[a-z]+$", <<"fooBAR">>},
       yconf:parse(File, #{a => yconf:binary("^[a-z]+$")})).

base64_test() ->
    File = file(["a: Zm9v"]),
    ?assertEqual(
       {ok, [{a, <<"foo">>}]},
       yconf:parse(File, #{a => yconf:base64()})).

bad_base64_test() ->
    File = file(["a: foo"]),
    ?checkError(
       {bad_base64, <<"foo">>},
       yconf:parse(File, #{a => yconf:base64()})).

atom_test() ->
    File = file(["a: atom"]),
    ?assertEqual(
       {ok, [{a, atom}]},
       yconf:parse(File, #{a => yconf:atom()})).

bad_atom_test() ->
    File = file(["a: []"]),
    ?checkError(
       {bad_atom, []},
       yconf:parse(File, #{a => yconf:atom()})).

bad_atom_length_test() ->
    Bad = list_to_binary(lists:duplicate(256, $z)),
    ?checkError(
       {bad_length, 255},
       yconf:validate(yconf:atom(), Bad)).

string_test() ->
    File = file(["a: foo"]),
    ?assertEqual(
       {ok, [{a, "foo"}]},
       yconf:parse(File, #{a => yconf:string()})).

bad_string_test() ->
    File = file(["a: []"]),
    ?checkError(
       {bad_binary, []},
       yconf:parse(File, #{a => yconf:string()})).

string_re_test() ->
    File = file(["a: foo",
		 "b: BAR",
		 "c: \"123\""]),
    ?assertEqual(
       {ok, [{a, "foo"}, {b, "BAR"}, {c, "123"}]},
       yconf:parse(File, #{a => yconf:string("^[a-z]+$"),
			   b => yconf:string("^[A-Z]+$"),
			   c => yconf:string("^[0-9]+$")})).

bad_string_re_test() ->
    File = file(["a: fooBAR"]),
    ?checkError(
       {nomatch, "^[a-z]+$", "fooBAR"},
       yconf:parse(File, #{a => yconf:string("^[a-z]+$")})).

binary_sep_test() ->
    File = file(["a: b/c//d//"]),
    ?assertEqual(
       {ok, [{a, [<<"b">>, <<"c">>, <<"d">>]}]},
       yconf:parse(File, #{a => yconf:binary_sep("/")})).

path_test() ->
    File = file(["a: foo"]),
    ?assertMatch(
       {ok, [{a, _}]},
       yconf:parse(File, #{a => yconf:path()})).

empty_path_test() ->
    File = file(["a: ''"]),
    ?checkError(
       empty_binary,
       yconf:parse(File, #{a => yconf:path()})).

file_read_test() ->
    File = file(""),
    File = file(["a: " ++ File]),
    ?assertMatch(
       {ok, [{a, _}]},
       yconf:parse(File, #{a => yconf:file()})).

bad_file_read_test() ->
    File = file(["a: non_existent"]),
    ?checkError(
       {read_file, enoent, _},
       yconf:parse(File, #{a => yconf:file()})).

file_write_test() ->
    File = file(""),
    File = file(["a: " ++ File]),
    ?assertMatch(
       {ok, [{a, _}]},
       yconf:parse(File, #{a => yconf:file(write)})).

bad_file_write_test() ->
    File = file(["a: " ++ test_dir()]),
    ?checkError(
       {create_file, eisdir, _},
       yconf:parse(File, #{a => yconf:file(write)})),
    File = file(["a: " ++ filename:join(File, "foo")]),
    ?checkError(
       {create_dir, eexist, _},
       yconf:parse(File, #{a => yconf:file(write)})).

directory_read_test() ->
    File = file(["a: " ++ test_dir()]),
    ?assertMatch(
       {ok, [{a, _}]},
       yconf:parse(File, #{a => yconf:directory()})).

bad_directory_read_test() ->
    File = file(["a: non_existent"]),
    ?checkError(
       {read_dir, enoent, _},
       yconf:parse(File, #{a => yconf:directory()})).

directory_write_test() ->
    File = file(["a: " ++ test_dir()]),
    ?assertMatch(
       {ok, [{a, _}]},
       yconf:parse(File, #{a => yconf:directory(write)})).

bad_directory_write_test() ->
    File = file(""),
    File = file(["a: " ++ File]),
    ?checkError(
       {create_dir, eexist, _},
       yconf:parse(File, #{a => yconf:directory(write)})).

url_test() ->
    File = file(["a: http://domain.tld",
		 "b: https://domain.tld"]),
    ?assertEqual(
       {ok, [{a, <<"http://domain.tld">>}, {b, <<"https://domain.tld">>}]},
       yconf:parse(File, #{a => yconf:url(), b => yconf:url()})).

url_any_test() ->
    File = file(["a: wss://domain.tld:8443"]),
    ?assertEqual(
       {ok, [{a, <<"wss://domain.tld:8443">>}]},
       yconf:parse(File, #{a => yconf:url([])})).

bad_url_scheme_test() ->
    File = file(["a: http://domain.tld"]),
    ?checkError(
       {bad_url, {unsupported_scheme, http}, <<"http://domain.tld">>},
       yconf:parse(File, #{a => yconf:url([https])})).

bad_url_host_test() ->
    File = file(["a: http:///path"]),
    ?checkError(
       {bad_url, empty_host, <<"http:///path">>},
       yconf:parse(File, #{a => yconf:url()})).

bad_url_no_default_port_test() ->
    File = file(["a: foo://domain.tld"]),
    ?checkError(
       {bad_url, {no_default_port, foo, _}, _},
       yconf:parse(File, #{a => yconf:url([])})).

bad_url_bad_port_test() ->
    File = file(["a: http://domain.tld:0"]),
    ?checkError(
       {bad_url, bad_port, _},
       yconf:parse(File, #{a => yconf:url([])})),
    File = file(["a: http://domain.tld:-1"]),
    ?checkError(
       {bad_url, bad_port, _},
       yconf:parse(File, #{a => yconf:url([])})),
    File = file(["a: http://domain.tld:65536"]),
    ?checkError(
       {bad_url, bad_port, _},
       yconf:parse(File, #{a => yconf:url([])})).

bad_url_test() ->
    File = file(["a: bad"]),
    ?checkError(
       {bad_url, _, <<"bad">>},
       yconf:parse(File, #{a => yconf:url()})).

octal_test() ->
    File = file(["a: \"644\""]),
    ?assertEqual(
       {ok, [{a, 420}]},
       yconf:parse(File, #{a => yconf:octal()})).

bad_octal_test() ->
    File = file(["a: \"9\""]),
    ?checkError(
       {bad_octal, <<"9">>},
       yconf:parse(File, #{a => yconf:octal()})).

ipv4_test() ->
    File = file(["a: 127.0.0.1"]),
    ?assertEqual(
       {ok, [{a, {127,0,0,1}}]},
       yconf:parse(File, #{a => yconf:ipv4()})).

bad_ipv4_test() ->
    File = file(["a: '::1'"]),
    ?checkError(
       {bad_ipv4, "::1"},
       yconf:parse(File, #{a => yconf:ipv4()})).

ipv6_test() ->
    File = file(["a: '::1'"]),
    ?assertEqual(
       {ok, [{a, {0,0,0,0,0,0,0,1}}]},
       yconf:parse(File, #{a => yconf:ipv6()})).

bad_ipv6_test() ->
    File = file(["a: 127.0.0.1"]),
    ?checkError(
       {bad_ipv6, "127.0.0.1"},
       yconf:parse(File, #{a => yconf:ipv6()})).

ip_test() ->
    File = file(["a: 127.0.0.1",
		 "b: '::1'"]),
    ?assertEqual(
       {ok, [{a, {127,0,0,1}}, {b, {0,0,0,0,0,0,0,1}}]},
       yconf:parse(File, #{a => yconf:ip(), b => yconf:ip()})).

bad_ip_test() ->
    File = file(["a: bad"]),
    ?checkError(
       {bad_ip, "bad"},
       yconf:parse(File, #{a => yconf:ip()})).

ip_mask_test() ->
    File = file(["a: 127.0.0.1",
		 "b: 127.0.0.1/0",
		 "c: 127.0.0.1/32",
		 "d: '::1'",
		 "e: '::1/0'",
		 "f: '::1/128'"]),
    ?assertEqual(
       {ok, [{a, {{127,0,0,1}, 32}},
	     {b, {{127,0,0,1}, 0}},
	     {c, {{127,0,0,1}, 32}},
	     {d, {{0,0,0,0,0,0,0,1}, 128}},
	     {e, {{0,0,0,0,0,0,0,1}, 0}},
	     {f, {{0,0,0,0,0,0,0,1}, 128}}]},
       yconf:parse(File, #{a => yconf:ip_mask(),
			   b => yconf:ip_mask(),
			   c => yconf:ip_mask(),
			   d => yconf:ip_mask(),
			   e => yconf:ip_mask(),
			   f => yconf:ip_mask()})).

bad_ip_mask_test() ->
    File = file(["a: 127.0.0.1/128"]),
    ?checkError(
       {bad_ip_mask, "127.0.0.1/128"},
       yconf:parse(File, #{a => yconf:ip_mask()})).

port_test() ->
    File = file(["a: 1",
		 "b: 65535"]),
    ?assertEqual(
       {ok, [{a, 1}, {b, 65535}]},
       yconf:parse(File, #{a => yconf:port(), b => yconf:port()})).

timeout_test() ->
    File = file(["millisecond: 1",
		 "second: 1",
		 "minute: 1",
		 "hour: 1",
		 "day: 1"]),
    ?assertEqual(
       {ok, [{millisecond, 1},
	     {second, 1000},
	     {minute, 60000},
	     {hour, 3600000},
	     {day, 86400000}]},
       yconf:parse(File, #{millisecond => yconf:timeout(millisecond),
			   second => yconf:timeout(second),
			   minute => yconf:timeout(minute),
			   hour => yconf:timeout(hour),
			   day => yconf:timeout(day)})).

timeout_atom_test() ->
    File = file(["a: '5'"]),
    ?assertEqual(
       {ok, [{a, 5}]},
       yconf:parse(File, #{a => yconf:timeout(millisecond)},
		   [plain_as_atom])).

timeout_format_test() ->
    File = file(["ms: 1 ms",
		 "msec: 1 msec",
		 "msecs: 1 msecs",
		 "millisec: 1 millisec",
		 "millisecs: 1 millisecs",
		 "millisecond: 1 millisecond",
		 "s: 1 s",
		 "sec: 1 sec",
		 "secs: 1 secs",
		 "second: 1 second",
		 "seconds: 1 seconds",
		 "m: 1 m",
		 "min: 1 min",
		 "mins: 1 mins",
		 "minute: 1 minute",
		 "minutes: 1 minutes",
		 "h: 1 h",
		 "hour: 1 hour",
		 "hours: 1 hours",
		 "d: 1 d",
		 "day: 1 day",
		 "days: 1 days"]),
    ?assertEqual(
       {ok, [{ms,1},
	     {msec,1},
	     {msecs,1},
	     {millisec,1},
	     {millisecs,1},
	     {millisecond,1},
	     {s,1000},
	     {sec,1000},
	     {secs,1000},
	     {second,1000},
	     {seconds,1000},
	     {m,60000},
	     {min,60000},
	     {mins,60000},
	     {minute,60000},
	     {minutes,60000},
	     {h,3600000},
	     {hour,3600000},
	     {hours,3600000},
	     {d,86400000},
	     {day,86400000},
	     {days,86400000}]},
       yconf:parse(File, #{'_' => yconf:timeout(millisecond)})).

timeout_infinity_test() ->
    File = file(["a: infinity",
		 "b: infinite",
		 "c: unlimited"]),
    ?assertEqual(
       {ok, [{a, infinite}, {b, unlimited}, {c, infinity}]},
       yconf:parse(File, #{a => yconf:timeout(day, infinite),
			   b => yconf:timeout(day, unlimited),
			   c => yconf:timeout(day, infinity)})).

bad_timeout_test() ->
    File = file(["a: []"]),
    ?checkError(
       {bad_timeout, []},
       yconf:parse(File, #{a => yconf:timeout(second)})),
    ?checkError(
       {bad_timeout, infinity, []},
       yconf:parse(File, #{a => yconf:timeout(second, infinity)})).

bad_timeout_zero_test() ->
    File = file(["a: 0"]),
    ?checkError(
       {bad_pos_int, 0},
       yconf:parse(File, #{a => yconf:timeout(second)})),
    ?checkError(
       {bad_pos_int, infinity, 0},
       yconf:parse(File, #{a => yconf:timeout(second, infinity)})).

bad_timeout_infinity_test() ->
    File = file(["a: foo"]),
    ?checkError(
       {bad_int, <<"foo">>},
       yconf:parse(File, #{a => yconf:timeout(second)})),
    ?checkError(
       {bad_enum, _, foo},
       yconf:parse(File, #{a => yconf:timeout(second, infinity)})).

bad_timeout_unit_test() ->
    File = file(["a: 1foo"]),
    ?checkError(
       {bad_timeout_unit, "foo"},
       yconf:parse(File, #{a => yconf:timeout(second)})).

bad_timeout_min_test() ->
    File = file(["a: 1ms"]),
    ?checkError(
       {bad_timeout_min, second},
       yconf:parse(File, #{a => yconf:timeout(second)})).

bad_timeout_negative_test() ->
    File = file(["a: -1s"]),
    ?checkError(
       {bad_pos_int, -1},
       yconf:parse(File, #{a => yconf:timeout(second)})),
    ?checkError(
       {bad_pos_int, infinity, -1},
       yconf:parse(File, #{a => yconf:timeout(second, infinity)})).

re_test() ->
    File = file(["a: ^[0-9]+$"]),
    ?assertMatch(
       {ok, [{a, _}]},
       yconf:parse(File, #{a => yconf:re()})).

bad_re_test() ->
    File = file(["a: '['"]),
    ?checkError(
       {bad_regexp, {_, _}, _},
       yconf:parse(File, #{a => yconf:re()})).

glob_test() ->
    File = file(["a: '*'"]),
    ?assertMatch(
       {ok, [{a, _}]},
       yconf:parse(File, #{a => yconf:glob()})).

bad_glob_test() ->
    File = file(["a: '['"]),
    ?checkError(
       {bad_glob, {_, _}, _},
       yconf:parse(File, #{a => yconf:glob()})).

beam_test() ->
    Exports = [[{foo, 1}, {parse, 2}], {parse, 3}, []],
    File = file(["a: yconf"]),
    ?assertMatch(
       {ok, [{a, yconf}]},
       yconf:parse(File, #{a => yconf:beam(Exports)})).

bad_beam_test() ->
    File = file(["a: foo"]),
    ?checkError(
       {bad_module, foo},
       yconf:parse(File, #{a => yconf:beam()})),
    File = file(["a: yconf"]),
    ?checkError(
       {bad_export, {foo, 1}, yconf},
       yconf:parse(File, #{a => yconf:beam([[{foo, 1}, {bar, 2}]])})),
    ?checkError(
       {bad_export, {foo, 1}, yconf},
       yconf:parse(File, #{a => yconf:beam([{foo, 1}])})).

non_empty_test() ->
    File = file(["a: [1,2,3]",
		 "b: 1",
		 "c: foo",
		 "d: {e: f}"]),
    ?assertMatch(
       {ok, [{a, [1,2,3]}, {b, 1}, {c, foo}, {d, [_]}]},
       yconf:parse(File, #{a => yconf:non_empty(yconf:list(yconf:int())),
			   b => yconf:non_empty(yconf:int()),
			   c => yconf:non_empty(yconf:atom()),
			   d => yconf:non_empty(yconf:map(yconf:any(), yconf:any()))})).

empty_atom_test() ->
    File = file(["a: ''"]),
    ?checkError(
       empty_atom,
       yconf:parse(File, #{a => yconf:non_empty(yconf:atom())})).

empty_binary_test() ->
    File = file(["a: ''"]),
    ?checkError(
       empty_binary,
       yconf:parse(File, #{a => yconf:non_empty(yconf:binary())})).

empty_list_test() ->
    File = file(["a: []"]),
    ?checkError(
       empty_list,
       yconf:parse(File, #{a => yconf:non_empty(yconf:list(yconf:any()))})).

empty_map_test() ->
    File = file(["a: {}"]),
    ?checkError(
       empty_list,
       yconf:parse(File, #{a => yconf:non_empty(
				  yconf:map(yconf:any(), yconf:any()))})).

list_test() ->
    File = file(["a: [1,2,3]"]),
    ?assertMatch(
       {ok, [{a, [1,2,3]}]},
       yconf:parse(File, #{a => yconf:list(yconf:any())})).

bad_list_test() ->
    File = file(["a: 1"]),
    ?checkError(
       {bad_list, 1},
       yconf:parse(File, #{a => yconf:list(yconf:any())})).

sorted_list_test() ->
    File = file(["a: [3,2,1]"]),
    ?assertMatch(
       {ok, [{a, [1,2,3]}]},
       yconf:parse(File, #{a => yconf:list(yconf:any(), [sorted])})).

bad_sorted_list_test() ->
    File = file(["a: 1"]),
    ?checkError(
       {bad_list, 1},
       yconf:parse(File, #{a => yconf:list(yconf:any(), [sorted])})).

unique_list_test() ->
    File = file(["a: [1,2,3]"]),
    ?assertMatch(
       {ok, [{a, [1,2,3]}]},
       yconf:parse(File, #{a => yconf:list(yconf:any(), [unique])})).

bad_unique_list_test() ->
    File = file(["a: [1,2,1,3]"]),
    ?checkError(
       {duplicated_value, 1},
       yconf:parse(File, #{a => yconf:list(yconf:any(), [unique])})),
    File = file(["a: [foo, bar, foo]"]),
    ?checkError(
       {duplicated_value, foo},
       yconf:parse(File, #{a => yconf:list(yconf:atom(), [unique])})),
    File = file(["a: [[1], [2], [1]]"]),
    ?checkError(
       {duplicated_value, [1]},
       yconf:parse(File, #{a => yconf:list(yconf:any(), [unique])})).

list_or_single_test() ->
    File = file(["a: 1",
		 "b: [1,2,3]"]),
    ?assertMatch(
       {ok, [{a, [1]}, {b, [1,2,3]}]},
       yconf:parse(File, #{a => yconf:list_or_single(yconf:any()),
			   b => yconf:list_or_single(yconf:any())})).

sorted_list_or_single_test() ->
    File = file(["a: 1",
		 "b: [3,2,1]"]),
    ?assertMatch(
       {ok, [{a, [1]}, {b, [1,2,3]}]},
       yconf:parse(File, #{a => yconf:list_or_single(yconf:any(), [sorted]),
			   b => yconf:list_or_single(yconf:any(), [sorted])})).

unique_list_or_single_test() ->
    File = file(["a: 1",
		 "b: [1,2,3]"]),
    ?assertMatch(
       {ok, [{a, [1]}, {b, [1,2,3]}]},
       yconf:parse(File, #{a => yconf:list_or_single(yconf:any(), [unique]),
			   b => yconf:list_or_single(yconf:any(), [unique])})).

bad_unique_list_or_single_test() ->
    File = file(["a: 1",
		 "b: [1,2,1,3]"]),
    ?checkError(
       {duplicated_value, 1},
       yconf:parse(File, #{a => yconf:list_or_single(yconf:any(), [unique]),
			   b => yconf:list_or_single(yconf:any(), [unique])})).

map_test() ->
    File = file(["a: {c: 2, b: 1}"]),
    ?assertEqual(
       {ok, [{a, [{c, 2}, {b, 1}]}]},
       yconf:parse(File, #{a => yconf:map(yconf:atom(), yconf:any())})),
    ?assertEqual(
       {ok, [{a, [{c, 2}, {b, 1}]}]},
       yconf:parse(File, #{a => yconf:map(yconf:atom(), yconf:any(),
					  [unique])})),
    ?assertEqual(
       {ok, [{a, [{b, 1}, {c, 2}]}]},
       yconf:parse(File, #{a => yconf:map(yconf:atom(), yconf:any(),
					  [{return, orddict}])})),
    ?assertEqual(
       {ok, [{a, #{b => 1, c => 2}}]},
       yconf:parse(File, #{a => yconf:map(yconf:atom(), yconf:any(),
					  [{return, map}])})),
    Ret = yconf:parse(File, #{a => yconf:map(yconf:atom(), yconf:any(),
					     [{return, dict}])}),
    ?assertMatch({ok, [{a, _}]}, Ret),
    ?assertEqual(
       [{b, 1}, {c, 2}],
       lists:keysort(1, dict:to_list(element(2, hd(element(2, Ret)))))).

bad_map_test() ->
    V = yconf:map(yconf:atom(), yconf:any()),
    File = file(["a: 1"]),
    ?checkError(
       {bad_map, 1},
       yconf:parse(File, #{a => V})),
    File = file(["a: [1,2,3]"]),
    ?checkError(
       {bad_map, [1,2,3]},
       yconf:parse(File, #{a => V})).

bad_unique_map_test() ->
    File = file(["a: {c: 2, b: 1, c: 3}"]),
    ?checkError(
       {duplicated_key, c},
       yconf:parse(File, #{a => yconf:map(yconf:atom(), yconf:any(),
					  [unique])})).

either_test() ->
    V = yconf:either(yconf:bool(), yconf:int()),
    File = file(["a: true",
		 "b: 5"]),
    ?assertEqual(
       {ok, [{a, true}, {b, 5}]},
       yconf:parse(File, #{a => V, b => V})).

either_atom_test() ->
    V = yconf:either(atom, yconf:int()),
    File = file(["a: atom",
		 "b: 1"]),
    ?assertEqual(
       {ok, [{a, atom}, {b, 1}]},
       yconf:parse(File, #{a => V, b => V})).

and_then_test() ->
    V = yconf:and_then(
	  yconf:list(yconf:int()),
	  fun lists:sum/1),
    File = file(["a: [1,2,3]"]),
    ?assertEqual(
       {ok, [{a, 6}]},
       yconf:parse(File, #{a => V})).

options_test() ->
    File = file(["a: {b: 1, c: true}"]),
    ?assertEqual(
       {ok, [{a, [{b, 1}, {c, true}]}]},
       yconf:parse(File, #{a => yconf:options(
				  #{b => yconf:int(),
				    c => yconf:bool(),
				    d => yconf:atom()})})).

options_return_map_test() ->
    File = file(["a: 1",
		 "b: 2"]),
    ?assertEqual(
       {ok, #{a => 1, b => 2}},
       yconf:parse(File, #{a => yconf:any(),
			   b => yconf:any()},
		   [{return, map}])).

options_return_dict_test() ->
    File = file(["a: 1",
		 "b: 2"]),
    Ret = yconf:parse(File, #{a => yconf:any(),
			      b => yconf:any()},
		      [{return, dict}]),
    ?assertMatch({ok, _}, Ret),
    ?assertEqual(
       [{a, 1}, {b, 2}],
       lists:keysort(1, dict:to_list(element(2, Ret)))).

options_return_orddict_test() ->
    File = file(["b: 1",
		 "a: 2"]),
    ?assertEqual(
       {ok, [{a, 2}, {b, 1}]},
       yconf:parse(File, #{a => yconf:any(),
			   b => yconf:any()},
		   [{return, orddict}])).

options_default_validator_test() ->
    File = file(["a: {b: 1, c: true}"]),
    ?assertEqual(
       {ok, [{a, [{b, 1}, {c, true}]}]},
       yconf:parse(File, #{a => yconf:options(
				  #{b => yconf:int(),
				    '_' => yconf:bool()})})).

bad_options_test() ->
    File = file(["a: 1"]),
    ?checkError(
       {bad_map, 1},
       yconf:parse(File, #{a => yconf:options(#{})})),
    File = file(["a: [1,2,3]"]),
    ?checkError(
       {bad_map, [1,2,3]},
       yconf:parse(File, #{a => yconf:options(#{})})).

bad_binary_map_option_test() ->
    File = file(["a: {b: foo}"]),
    ?checkError(
       {bad_bool, foo},
       yconf:parse(File, #{a => yconf:map(yconf:binary(), yconf:bool())})).

bad_integer_map_option_test() ->
    File = file(["a: {1: foo}"]),
    ?checkError(
       {bad_bool, foo},
       yconf:parse(File, #{a => yconf:map(yconf:int(), yconf:bool())})).

unknown_option_test() ->
    File = file(["a: 1"]),
    ?checkError(
       {unknown_option, [define_macro], a},
       yconf:parse(File, #{}, [replace_macros])).

missing_option_test() ->
    File = file(["a: 1"]),
    ?checkError(
       {missing_option, b},
       yconf:parse(File, #{a => yconf:int(),
			   b => yconf:any()},
		   [{required, [b]}])).

disallowed_option_test() ->
    File = file(["a: 1",
		 "b: 2"]),
    ?checkError(
       {disallowed_option, b},
       yconf:parse(File, #{a => yconf:int()},
		   [{disallowed, [b]}])),
    ?checkError(
       {disallowed_option, b},
       yconf:parse(File, #{a => yconf:int(), b => yconf:int()},
		   [{disallowed, [b]}])),
    ?checkError(
       {disallowed_option, b},
       yconf:parse(File, #{a => yconf:int(), b => yconf:int()},
		   [{required, [b]}, {disallowed, [b]}])).

unknown_option_with_disallowed_test() ->
    File = file(["a: 1",
		 "c: 2"]),
    ?checkError(
       {unknown_option, [a], c},
       yconf:parse(File, #{a => yconf:int(), b => yconf:int()},
		   [{disallowed, [b]}])).

duplicated_option_test() ->
    File = file(["a: 1",
		 "b: 2",
		 "a: 3"]),
    ?checkError(
       {duplicated_option, a},
       yconf:parse(File, #{a => yconf:int(), b => yconf:int()},
		   [unique])),
    ?assertEqual(
       {ok, [{a, 1}, {b, 2}, {a, 3}]},
       yconf:parse(File, #{a => yconf:int(), b => yconf:int()}, [])).

duplicated_unknown_option_test() ->
    File = file(["a: 1",
		 "b: 2",
		 "b: 3"]),
    ?checkError(
       {duplicated_option, b},
       yconf:parse(File, #{a => yconf:int(),
			   '_' => yconf:any()},
		   [unique])).

bad_cwd_test() ->
    test_format_error({error, {bad_cwd, eaccess}, []}).

unknown_reason_test() ->
    test_format_error({error, foo, []}).

unicode_test() ->
    UTF8CharList = [209,134],
    UTF8CharBin = list_to_binary(UTF8CharList),
    UTF8CharAtom = list_to_atom(UTF8CharList),
    File = file(["a: " ++ UTF8CharList,
		 "b: " ++ UTF8CharList]),
    ?assertEqual(
       {ok, [{a, UTF8CharAtom}, {b, UTF8CharBin}]},
       yconf:parse(File, #{a => yconf:atom(),
			   b => yconf:binary()},
		   [plain_as_atom])),
    ?assertEqual(
       {ok, [{a, UTF8CharAtom}, {b, UTF8CharBin}]},
       yconf:parse(File, #{a => yconf:atom(),
			   b => yconf:binary()})).

stop_test() ->
    ?assertEqual(ok, yconf:stop()).

%%%===================================================================
%%% Internal functions
%%%===================================================================
test_dir() ->
    {ok, Cwd} = file:get_cwd(),
    filename:join(filename:dirname(Cwd), "test").

file(Data) ->
    file("test.yml", Data).

included_file(Data) ->
    file("included.yml", Data).

file(FileName, Data) ->
    Path = filename:join(test_dir(), FileName),
    ok = file:write_file(Path, string:join(Data, io_lib:nl())),
    Path.

test_format_error({error, Why, Ctx}) ->
    ?assertMatch([_|_], yconf:format_error(Why, Ctx)).
