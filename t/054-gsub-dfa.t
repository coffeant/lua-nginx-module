# vim:set ft= ts=4 sw=4 et fdm=marker:
use lib 'lib';
use Test::Nginx::Socket::Lua;

#worker_connections(1014);
#master_on();
#workers(2);
#log_level('warn');

repeat_each(2);

plan tests => repeat_each() * (blocks() * 2 + 5);

#no_diff();
no_long_string();
run_tests();

__DATA__

=== TEST 1: matched with d
--- config
    location /re {
        content_by_lua '
            local s, n = ngx.re.gsub("hello, 1234 5678", "[0-9]|[0-9][0-9]", "world", "d")
            if n then
                ngx.say(s, ": ", n)
            else
                ngx.say(s)
            end
        ';
    }
--- request
    GET /re
--- response_body
hello, worldworld worldworld: 4



=== TEST 2: not matched with d
--- config
    location /re {
        content_by_lua '
            local s, n = ngx.re.gsub("hello, world", "[0-9]+", "hiya", "d")
            if n then
                ngx.say(s, ": ", n)
            else
                ngx.say(s)
            end
        ';
    }
--- request
    GET /re
--- response_body
hello, world: 0



=== TEST 3: matched with do
--- config
    location /re {
        content_by_lua '
            local s, n = ngx.re.gsub("hello, 1234 5678", "[0-9]|[0-9][0-9]", "world", "do")
            if n then
                ngx.say(s, ": ", n)
            else
                ngx.say(s)
            end
        ';
    }
--- request
    GET /re
--- response_body
hello, worldworld worldworld: 4



=== TEST 4: not matched with do
--- config
    location /re {
        content_by_lua '
            local s, n = ngx.re.gsub("hello, world", "[0-9]+", "hiya", "do")
            if n then
                ngx.say(s, ": ", n)
            else
                ngx.say(s)
            end
        ';
    }
--- request
    GET /re
--- response_body
hello, world: 0



=== TEST 5: bad pattern
--- config
    location /re {
        content_by_lua '
            local s, n, err = ngx.re.gsub("hello\\nworld", "(abc", "world", "j")
            if s then
                ngx.say("gsub: ", n)

            else
                ngx.say("error: ", err)
            end
        ';
    }
--- request
    GET /re
--- response_body
error: pcre_compile() failed: missing ) in "(abc"



=== TEST 6: bad pattern + o
--- config
    location /re {
        content_by_lua '
            local s, n, err = ngx.re.gsub("hello\\nworld", "(abc", "world", "jo")
            if s then
                ngx.say("gsub: ", n)
            else
                ngx.say("error: ", err)
            end
        ';
    }
--- request
    GET /re
--- response_body
error: pcre_compile() failed: missing ) in "(abc"
--- no_error_log
[error]



=== TEST 7: UTF-8 mode without UTF-8 sequence checks
--- config
    location /re {
        content_by_lua '
            local s, n, err = ngx.re.gsub("你好", ".", "a", "Ud")
            if s then
                ngx.say("s: ", s)
            end
        ';
    }
--- stap
probe process("$LIBPCRE_PATH").function("pcre_compile") {
    printf("compile opts: %x\n", $options)
}

probe process("$LIBPCRE_PATH").function("pcre_dfa_exec") {
    printf("exec opts: %x\n", $options)
}

--- stap_out
compile opts: 800
exec opts: 2000
exec opts: 2000
exec opts: 2000

--- request
    GET /re
--- response_body
s: aa
--- no_error_log
[error]



=== TEST 8: UTF-8 mode with UTF-8 sequence checks
--- config
    location /re {
        content_by_lua '
            local s, n, err = ngx.re.gsub("你好", ".", "a", "ud")
            if s then
                ngx.say("s: ", s)
            end
        ';
    }
--- stap
probe process("$LIBPCRE_PATH").function("pcre_compile") {
    printf("compile opts: %x\n", $options)
}

probe process("$LIBPCRE_PATH").function("pcre_dfa_exec") {
    printf("exec opts: %x\n", $options)
}

--- stap_out
compile opts: 800
exec opts: 0
exec opts: 0
exec opts: 0

--- request
    GET /re
--- response_body
s: aa
--- no_error_log
[error]



=== TEST 9: bug: gsub incorrectly swallowed a character is the first character
Original bad result: estCase
--- config
    location /re {
        content_by_lua '
            local s, n = ngx.re.gsub("TestCase", "^ *", "", "")
            if s then
                ngx.say(s)
            end
        ';
    }
--- request
    GET /re
--- response_body
TestCase



=== TEST 10: bug: gsub incorrectly swallowed a character is not the first character
Original bad result: .b.d
--- config
    location /re {
        content_by_lua '
            local s, n = ngx.re.gsub("abcd", "a|(?=c)", ".", "")
            if s then
                ngx.say(s)
            end
        ';
    }
--- request
    GET /re
--- response_body
.b.cd
