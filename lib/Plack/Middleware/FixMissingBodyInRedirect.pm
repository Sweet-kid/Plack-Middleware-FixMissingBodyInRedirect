package Plack::Middleware::FixMissingBodyInRedirect;
use strict;
use warnings;
use parent qw( Plack::Middleware );

use Plack::Util;
use HTML::Entities;
# ABSTRACT: Plack::Middleware which sets body for redirect response, if it's not already set

sub call {
    my ($self, $env) = @_;

    my $res = $self->app->($env);

    return $self->response_cb($res, sub {
        my $response = shift;
        return unless $response->[0] =~/3\d\d/; # only handle redirect statuses.
        my $headers = Plack::Util::headers($response->[1]); # first index contains HTTP header
        if( $headers->exists('Location') ) {
            my $location = $headers->get("Location");
            my $encoded_location = encode_entities($location);
            # checking if body (which is at index 2) is set or not
            if ( !_is_body_set($response)) {
                my $body =<<"EOF";
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
    <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
    <title>Moved</title>
    </head>
    <body>
   <p>This item has moved <a href="$encoded_location">here</a>.</p>
</body>
</html>
EOF
                $response->[2] = [$body]; # body should be either an array ref or file handle
                $headers->set('Location' => $encoded_location);
                $headers->set('Content-Type' => 'text/html; charset=utf-8');
                $headers->set('Content-Length' => length($body));
                return $response;
            }
        }
    });
}

sub _is_body_set {
    my $response_ref = shift;
    my @response = @$response_ref;
    if( scalar( @response ) == 3 ) {
        my $body_ref = $response[2];
        my $body_ref_type = ref( $body_ref );
        if( $body_ref_type eq "ARRAY" ) {
            my @body = @$body_ref;
            if( scalar( @body ) == 0 ) {
                # if size of the body array is 0, then it's not set, so return false
                return 0;
            } else {
                foreach my $element ( @body ) {
                    if( defined $element && $element =~ /.+/ ) {
                        # if even a single $element is set, then body is set, so return true
                        return 1;
                    }
                }
                # flow will reach this statement only after traversing
                # the whole body array in above foreach loop, which means that
                # no element is set in the body array, so return false
                return 0;
            }
        } elsif( $body_ref_type eq "GLOB" ) {
            if( -z $body_ref ) {
                return 0;
            } else {
                return 1;
            }
        }
    }
}

1;
__END__

=head1 NAME

Plack::Middleware::FixMissingBodyInRedirect - set body for redirect response, if it's not already set

=head1 SYNOPSIS

   use strict;
   use warnings;

   use Plack::Builder;

   my $app = sub { ...  };

   builder {
       enable "FixMissingBodyInRedirect";
       $app;
   };

=head1 DESCRIPTION

This module sets body in redirect response, if it's not already set.

=cut
