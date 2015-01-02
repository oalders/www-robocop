use strict;
use warnings;

package WWW::RoboCop;

use Moose;

use MooseX::StrictConstructor;
use MooseX::Types::Common::String qw( SimpleStr );
use URI;

has follow_link_callback => (
    is      => 'ro',
    isa     => 'CodeRef',
    default => sub { return 1 },
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
    isa     => 'HashRef',
    traits  => ['Hash'],
    handles => {
        _add_url_to_history => 'set',
        _has_processed_url  => 'exists',
    },
    init_arg => undef,
    default  => sub { +{} },
);

sub _get {
    my $self = shift;
    my $url  = shift;
    my $referring_url = shift;

    $self->ua->get( $url );
    $self->_add_url_to_history( $url => { status => $self->ua->status } );

    my @links = $self->ua->find_all_links;

    foreach my $link ( @links ) {
        my $uri = URI->new( $link->url_abs );
        $uri->fragment( undef );    # fragments result in duplicate urls
        next if $self->_has_processed_url( $uri->as_string );
        if ( $self->follow_link_callback->( $link, $referring_url ) ) {
            $self->_get( $uri->as_string );
        }
    }
}

sub crawl {
    my $self = shift;
    my $url  = shift;
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

=cut
