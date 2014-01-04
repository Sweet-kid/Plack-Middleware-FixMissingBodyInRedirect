package Plack::Middleware::FixMissingBodyInRedirect;
use strict;
use warnings;
use parent qw( Plack::Middleware );

use Plack::Util;
use HTML::Entities;

sub call {
    my ($self, $env) = @_;

    my $res = $self->app->($env);

    return $self->response_cb($res, sub {
	my $response = shift;
	my $headers = Plack::Util::headers($response->[1]); # first index contains HTTP header
	if( $headers->exists('Location') ) {
	    my $location = $headers->get("Location");
	    $self->log->debug(qq/Redirecting to "$location"/) if $self->app->debug;
	    if ( !$response->[2] ) {
		print "inside if\n";
		my $encoded_location = encode_entities($location);
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
                $response->[2] = $body;
                $headers->push('Content-Type' => 'text/html; charset=utf-8');
		$headers->push('Location' => $encoded_location);
		return $response;
	    }
	}
    });
}
 
1;
