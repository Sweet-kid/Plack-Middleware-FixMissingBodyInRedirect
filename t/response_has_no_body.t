use strict;
use warnings;
use Test::More;
use Plack::Test;
use Plack::Builder;
use HTTP::Request::Common;
use Carp::Always;

test_psgi app => builder {
    enable 'FixMissingBodyInRedirect';

    mount '/empty_array' => sub {
        [302,
         [ "Location" => '/xyz',
           "Content-Type" => 'text/html; charset=utf-8'],
         []];
    };

    mount '/array_with_one_undef' => sub {
        [302,
         [ "Location" => '/xyz',
           "Content-Type" => 'text/html; charset=utf-8'],
           [undef]];
    };

    mount '/first_undef_rest_def' => sub {
        [302,
         [ "Location" => '/xyz',
           "Content-Type" => 'text/html; charset=utf-8'],
         [undef, "<html><body>Only first element was undef</body></html>"]];
    };

    mount '/already_set_body' => sub {
        [302,
         [ "Location" => '/xyz',
           "Content-Type" => 'text/html; charset=utf-8'],
         ["<html><body>Body is set</body></html>"]];
    };

    mount '/body_with_size_zero_file_handle' => sub {
        open(my $fh, ">", "output.txt")
            or die "cannot open > output.txt: $!";
        close $fh;
        open $fh, "<", "output.txt";
        [302,
         [ "Location" => '/xyz',
           "Content-Type" => 'text/html; charset=utf-8'],
         $fh];
    };

    mount '/body_with_good_file_handle' => sub {
        open(my $fh, ">", "output.txt")
            or die "cannot open > output.txt: $!";
        my $text = "<html><body>I'm file's text</body></html>";
        print $fh $text;
        close $fh;
        open $fh, "<", "output.txt";
        [302,
         [ "Location" => '/xyz',
           "Content-Type" => 'text/html; charset=utf-8'],
         $fh];
    };
},
client => sub {
    my $cb = shift;

    my @responses = (
        [ '/empty_array',
          qr/<body>/,
          302,
          'text/html; charset=utf-8' ],
        [ '/array_with_one_undef',
          qr/<body>/,
          302,
          'text/html; charset=utf-8' ],
        [ '/first_undef_rest_def',
          qr!<body>Only first element was undef</body>!,
          302,
          'text/html; charset=utf-8' ],
        [ '/already_set_body',
          qr!<html><body>Body is set</body></html>!,
          302,
          'text/html; charset=utf-8' ],
        [ '/body_with_size_zero_file_handle',
          qr!<body>!,
          302,
          'text/html; charset=utf-8' ],
        [ '/body_with_good_file_handle',
          qr!<html><body>I'm file's text</body></html>!,
          302,
          'text/html; charset=utf-8' ],
    );

    foreach my $response ( @responses ) {
        my @response_array = @$response;
        my $route          = $response_array[0],
        my $content        = $response_array[1];
        my $response_code  = $response_array[2];
        my $content_type   = $response_array[3];
        my $res            = $cb->(GET $route);

        like( $res->content,
              $content,
              "Content for $route matches $content");

        is( $res->code,
            $response_code,
            "Response code for $route is $response_code" );

        is( $res->header('Content-Type'),
            $content_type,
            "Content-Type for $route is $content_type");
    }
};

unlink "output.txt";
done_testing;
