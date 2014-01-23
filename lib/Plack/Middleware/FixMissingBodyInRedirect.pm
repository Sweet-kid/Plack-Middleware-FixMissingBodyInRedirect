package Plack::Middleware::FixMissingBodyInRedirect;
use strict;
use warnings;
use parent qw( Plack::Middleware );

use Plack::Util;
use HTML::Entities;
use Scalar::Util;
use Plack::Middleware::FixMissingBodyInRedirect::Proxy;
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
                my $body = $self->_default_html_body($encoded_location);
                $response->[2] = [$body];
                my $content_length = Plack::Util::content_length($body);
                $headers->set('Content-Length' => $content_length);
                $headers->set('Content-Type' => 'text/html; charset=utf-8');
            }

            ## Streaming case...
            if(scalar( @$response ) == 2 ) {
              my $first_call = 1;
              if(! $headers->exists('Content-Type')) {
                $headers->set('Content-Type' => 'text/html; charset=utf-8')
              } else {
                # Well, if there's a content-type, one hopes there's content
                # but at this point we can't really determine...  So this
                # means we might return default content that doesn't match the
                # declared content type :(
              }
              return sub {
                my $chunk = shift;
                if( $first_call && !defined($chunk) ) {
                  $first_call = 0;
                  $chunk = $self->_default_html_body($encoded_location);
                }
                return $chunk;
              };
            }

            ## Filehandle like object case
            if(Scalar::Util::blessed($response->[2]) and $response->[2]->can('getline')) {
              if(! $headers->exists('Content-Type')) {
                $headers->set('Content-Type' => 'text/html; charset=utf-8')
              } else {
                # Well, if there's a content-type, one hopes there's content
                # but at this point we can't really determine...  So this
                # means we might return default content that doesn't match the
                # declared content type :(
              }
              $response->[2] = Plack::Middleware::FixMissingBodyInRedirect::Proxy->new(
                $response->[2], $self->_default_html_body($encoded_location));
            }
        }
    });
}

sub _default_html_body {
  my ($self_or_class, $encoded_location) = @_;
  return <<"EOF";
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
        } elsif(Scalar::Util::blessed($response[2]) and $response[2]->can('getline')) {
          # Well, this totally sucks, we have a filehandle like object but we can't
          # test if it has any contents because the PSGI spec only requires getline.
          # For now we assume "all is well', we handle this above (sorta...)
          return 1;
        }
    } else {
      # This is the streaming case.  for now we assume "all is well', we handle this
      # above (sorta...)
      return 1;
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
