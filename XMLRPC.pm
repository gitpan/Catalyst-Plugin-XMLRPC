package Catalyst::Plugin::XMLRPC;

use strict;
use base 'Class::Data::Inheritable';
use Catalyst::Utils;
use RPC::XML;
use RPC::XML::Parser;

our $VERSION = '0.01';

__PACKAGE__->mk_classdata('_xmlrpc_parser');
__PACKAGE__->_xmlrpc_parser( RPC::XML::Parser->new );

=head1 NAME

Catalyst::Plugin::XMLRPC - Dispatch XMLRPC with Catalyst

=head1 SYNOPSIS

    # include it in plugin list
    use Catalyst qw/XMLRPC/;

    # Public action to redispatch
    sub entrypoint : Global {
        my ( $self, $c ) = @_;
        $c->xmlrpc;
    }

    # Methods with Remote attribute in same class
    sub echo : Remote {
        my ( $self, $c, @args ) = @_;
        return join ' ', @args;
    }

    sub add : Remote {
        my ( $self, $c, $a, $b ) = @_;
        return $a + $b;
    }

=head1 DESCRIPTION

This plugin allows your controller class to dispatch XMLRPC methods
from it's own class.

=head2 METHODS

=head3 $c->xmlrpc


Call this method from a controller action to set it up as a endpoint
for RPC methods in the same class.

=cut

sub xmlrpc {
    my $c = shift;

    # Deserialize
    my $req = $c->_deserialize_xmlrpc;

    my $res = 0;

    # We have a method
    if ( my $method = $req->{method} ) {

        # We have matching action
        my $class = $req->{class} || '';
        if ($class) {
            my $prefix = Catalyst::Utils::class2classprefix( caller(0) );
            $class = "$prefix\::$class";
        }
        else { $class = caller(0) }
        if ( my $code = $class->can($method) ) {

            # Find attribute
            my $remote = 0;
            for my $attr ( @{ Catalyst::Utils::attrs($code) } ) {
                $remote++ if $attr eq 'Remote';
            }

            # We have attribute
            if ($remote) {
                $class = $c->components->{$class} || $class;
                my $args = join '', @{ $req->{args} };
                my @args = @{ $c->req->args };
                $c->req->args( $req->{args} );
                $c->actions->{reverse}->{$code} ||= "$class->$method";
                $c->state( $c->execute( $class, $code ) );
                $res = $c->state;
                $c->req->args( \@args );
            }

            else {
                $c->log->debug(qq/Method "$method" has no Remote attribute/)
                  if $c->debug;
            }
        }

        else {
            $c->log->debug(qq/Couldn't find xmlrpc method "$method"/)
              if $c->debug;
        }

    }

    # Serialize response
    $c->_serialize_xmlrpc($res);
    return 0;
}

# Deserializes the xml in $c->req->body
sub _deserialize_xmlrpc {
    my $c = shift;

    my $p = $c->_xmlrpc_parser->parse;
    $p->parse_more( $c->req->body );
    my $req = $p->parse_done;

    # Handle . in method name
    my $name  = $req->name;
    my $class = '';
    $name =~ s/\.+/\:\:/g;
    if ( $name =~ /^(?:\:\:)?(.*)$/ ) {
        $name = $1;
        if ( $name =~ /(^[\w\:]+)\:\:(\w+)$/ ) {
            $class = $1;
            $name  = $2;
        }
    }
    my @args = map { $_->value } @{ $req->args };

    return { class => $class, method => $name, args => \@args };
}

# Serializes the response to $c->res->body
sub _serialize_xmlrpc {
    my ( $c, $status ) = @_;
    my $res = RPC::XML::response->new($status);
    $c->res->content_type('text/xml');
    $c->res->body( $res->as_string );
}

=head1 NEW ACTION ATTRIBUTES

=over 4

=item Remote

The "Remote" attribute indicates that this action can be dispatched
through RPC mechanisms like XML-RPC

=back

=head1 SEE ALSO

L<Catalyst::Manual>, L<Catalyst::Test>, L<Catalyst::Request>,
L<Catalyst::Response>, L<Catalyst::Helper>, L<RPC::XML>

=head1 AUTHOR

Marcus Ramberg <mramberg@cpan.org>
Christian Hansen
Sebastian Riedel, C<sri@oook.de>

=head1 LICENSE

This library is free software . You can redistribute it and/or modify 
it under the same terms as perl itself.

=cut

1;
