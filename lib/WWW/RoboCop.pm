use strict;
use warnings;

package WWW::RoboCop;

use Carp qw( croak );
use Moose;
use MooseX::StrictConstructor;
use MooseX::Types::Moose qw( CodeRef HashRef );
use URI;

has is_url_whitelisted => (
    is       => 'ro',
    isa      => CodeRef,
    traits   => ['Code'],
    handles  => { _should_follow_link => 'execute' },
    required => 1,
);

has report_for_url => (
    is      => 'ro',
    isa     => CodeRef,
    traits  => ['Code'],
    handles => { _log_response => 'execute' },
    default => sub {
        sub { return { status => $_[0]->code } }
    },
);

has ua => (
    is      => 'ro',
    isa     => 'WWW::Mechanize',
    default => sub {
        require Mozilla::CA;
        require WWW::Mechanize;
        WWW::Mechanize->new( autocheck => 0 );
    },
);

has _history => (
    is      => 'ro',
    isa     => HashRef,
    traits  => ['Hash'],
    handles => {
        _add_url_to_history => 'set',
        _has_processed_url  => 'exists',
    },
    init_arg => undef,
    default  => sub { +{} },
);

sub _get {
    my $self          = shift;
    my $url           = shift;
    my $referring_url = shift;

    my $response = $self->ua->get( $url );
    my $report = $self->_log_response( $response, $referring_url );
    $self->_add_url_to_history( $url, $report );

    my @links = $self->ua->find_all_links;

    foreach my $link ( @links ) {
        my $uri = URI->new( $link->url_abs );
        $uri->fragment( undef );    # fragments result in duplicate urls

        next if $self->_has_processed_url( $uri->as_string );
        next unless $uri->can( 'host' );    # no mailto: links
        next unless $self->_should_follow_link( $link, $referring_url );

        $self->_get( $uri->as_string, $url );
    }
}

sub crawl {
    my $self = shift;
    my $url  = shift;
    croak 'URL required' if !$url;

    $self->_get( $url );
}

sub get_report {
    my $self = shift;
    return $self->_history;
}

1;

__END__

# ABSTRACT: Police your URLs!

=pod

=head1 DESCRIPTION

BETA BETA BETA!

WWW::RoboCop is a dead simple, somewhat opinionated robot.  Given a starting
page, this module will crawl only URLs which have been whitelisted by the
is_url_whitelisted() callback.  It then creates a report of all visited pages,
keyed on URL.  You are encouraged to provide your own report creation callback
so that you can collect all of the information which you require for each URL.

=head1 SYNOPSIS

    use WWW::RoboCop;

    my $count = 0;
    my $robocop = WWW::RoboCop->new(
        is_url_whitelisted => sub {
            return $count++ < 5; # just crawl 5 URLs
        },
    );

    $robocop->crawl( 'http://host.myhost.com/start' );

    my $history = $robocop->get_report;

    # $history = {
    #    'http://myhost.com/one' => { status => 200 },
    #    'http://myhost.com/two' => { status => 404 },
    #}

=head1 CONSTRUCTOR AND STARTUP

=head2 new()

Creates and returns a new WWW::RoboCop object.

Below are the arguments which you may pass to new() when creating an object.

=head3 is_url_whitelisted

This argument is required.  You must provide an anonymous subroutine which will
return true or false based on some arbitrary criteria which you provide.  The
two arguments to this anonymous subroutine will be a L<WWW::Mechanize::Link>
object as well as the referring URL.

Your sub might look something like this:

    use feature qw( state );

    my $whitelister = sub {
        my $link          = shift;
        my $referring_url = shift;

        state $count = 0;

        # find 404s on your site by spidering the first outbound link and
        # stopping there

        return 1
            if $link->URI->host
            && $link->URI->host !~ m{myhost.com}
            && $referring_url
            && $referring_url ~= m{myhost.com};

        return 0
            if $link->URI->host
            && $link->URI->host !~ m{myhost.com};

        # set an upper limit on URLs to crawl
        ++$count;
        return 0 if $count > 200;
        return 1;
    };

    my $robocop = WWW::RoboCop->new(
        is_url_whitelisted => $whitelister
    );

=head3 report_for_url

This argument is not required, but is highly recommended. The arguments to this
anonymous subroutine will be an L<HTTP::Response> object as well as the
referring URL.  Your sub might look something like this:

    my $reporter = sub {
        my $response      = shift;    # HTTP::Response object
        my $referring_url = shift;    # URL as plain old string
        return {
            redirects => [
                map { +{ status => $_->code, uri => $_->base->as_string } }
                    $res->redirects
            ],
            referrer => $referring_url,
            status   => $res->code,
        };
    };

    my $robocop = WWW::RoboCop->new(
        is_url_whitelisted => ...,
        report_for_url     => $reporter,
    );

That would give you a HashRef with the status code for each link visited (200,
404, 500, etc) as well as the referring URL (the page on which the link was
found) and a list of any redirects which were followed in order to get to this
URL.

=head3 ua( WWW::Mechanize )

You can provide your own UserAgent object to this class.  It should be of the
L<WWW::Mechanize> family.  If you're looking for a significant speed boost
while under development, consider providing a L<WWW::Mechanize::Cached> object.
This can give you enough of a speedup to save you from getting distracted
and going off to read Hacker News while you wait.


    my $robocop = WWW::RoboCop->new(
        is_url_whitelisted => ...,
        ua => WWW::Mechanize::Cached->new( cache => $CHI ),
    );

=head2 crawl( $url )

This method sets the WWW::RoboCop in motion.  The robot will only come to a
halt once has exhausted all of the whitelisted URLs it can find.

=head2 get_report

This method returns a HashRef of crawling results, keyed on the URLs visited.
By default, it returns a very simple HashRef, containing only the status code
of the visited URL.  You are encouraged to provide your own callback so that
you can get a detailed report returned to you.  You can do this by providing a
report_for_url callback when instantiating the object.

The default report looks something like this:

    # $history = {
    #    'http://myhost.com/one' => { status => 200 },
    #    'http://myhost.com/two' => { status => 404 },
    #}

So, you can see that it's worthwhile to whip up a little something special for
yourself.

=cut
