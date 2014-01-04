use strict;
use warnings;
use Test::More;
use Plack::Test;
use Plack::Builder;
use HTTP::Request::Common;
use Carp::Always;

test_psgi app => builder {
    enable 'FixMissingBodyInRedirect';
    sub {
	my $env = shift;
	[302,
	 [ "Location" => '/xyz',
	   "Content-Type" => 'text/html; charset=utf-8'],
	 ''];
    }
},
client => sub {
    my $cb = shift;

    my $res = $cb->(GET "/");
    like( $res->content, qr/<body>/, "Content has HTML body" );
    is( $res->code, 302, 'Response Code' );
    is( $res->header( 'Content-Type' ), 'text/html; charset=utf-8', 'Content Type' );
};

done_testing;
