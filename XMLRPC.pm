package Catalyst::Plugin::XMLRPC;

use strict;
use base 'Class::Data::Inheritable';
use attributes ();
use RPC::XML;
use RPC::XML::Parser;
use Catalyst::Action;
use Catalyst::Utils;

our $VERSION = '0.06';

__PACKAGE__->mk_classdata('_xmlrpc_parser');
__PACKAGE__->_xmlrpc_parser( RPC::XML::Parser->new );

=head1 NAME

Catalyst::Plugin::XMLRPC - Dispatch XMLRPC methods with Catalyst

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
from its own class.

=head2 METHODS

=over 4

=item $c->xmlrpc(%attrs)

Call this method from a controller action to set it up as a endpoint
for RPC methods in the same class.

Supported attributes:
    class: name of class to dispatch (defaults to current one)
    method: method to dispatch to (overrides xmlrpc method)

=cut

sub xmlrpc {
    my $c     = shift;
    my $attrs = @_ > 1 ? {@_} : $_[0];

    # Deserialize
    my $req;
    eval { $req = $c->_deserialize_xmlrpc };
    if ( $@ || !$req ) {
        $c->log->debug(qq/Invalid XMLRPC request "$@"/);
        $c->_serialize_xmlrpc( RPC::XML::fault->new( -1, 'Invalid request' ) );
        return 0;
    }

    my $res = 0;

    # We have a method
    my $method = $attrs->{method} || $req->{method};
    if ($method) {

        # We have matching action
        my $class = $attrs->{class} || caller(0);
        if ( my $code = $class->can($method) ) {

            # Find attribute
            my $remote = 0;
            my $attrs = attributes::get($code) || [];
            for my $attr (@$attrs) {
                $remote++ if $attr eq 'Remote';
            }

            # We have attribute
            if ($remote) {
                $class = $c->components->{$class} || $class;
                my @args = @{ $c->req->args };
                $c->req->args( $req->{args} );
                my $name = ref $class || $class;
                my $action = Catalyst::Action->new(
                    {
                        name      => $method,
                        code      => $code,
                        reverse   => "-> $name->$method",
                        class     => $name,
                        namespace => Catalyst::Utils::class2prefix(
                            $name, $c->config->{case_sensitive}
                        ),
                    }
                );
                $c->state( $c->execute( $class, $action ) );
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
    return $res;
}

# Deserializes the xml in $c->req->body
sub _deserialize_xmlrpc {
    my $c = shift;

    my $p       = $c->_xmlrpc_parser->parse;
    my $body    = $c->req->body;
    my $content = do { local $/; <$body> };
    $p->parse_more($content);
    my $req = $p->parse_done;

    # Handle . in method name
    my $name = $req->name;
    $name =~ s/\.//g;
    my @args = map { $_->value } @{ $req->args };

    return { method => $name, args => \@args };
}

# Serializes the response to $c->res->body
sub _serialize_xmlrpc {
    my ( $c, $status ) = @_;
    my $res = RPC::XML::response->new($status);
    $c->res->content_type('text/xml');
    $c->res->body( $res->as_string );
}

=back 

=head2 NEW ACTION ATTRIBUTES

=over 4

=item Remote

The "Remote" attribute indicates that this action can be dispatched
through RPC mechanisms like XML-RPC

=back

=head1 SEE ALSO

L<Catalyst::Manual>, L<Catalyst::Test>, L<Catalyst::Request>,
L<Catalyst::Response>, L<Catalyst::Helper>, L<RPC::XML>

=head1 AUTHOR

Sebastian Riedel, C<sri@oook.de>
Marcus Ramberg, C<mramberg@cpan.org>
Christian Hansen
Yoshinori Sano

=head1 LICENSE

This library is free software, you can redistribute it and/or modify 
it under the same terms as Perl itself.

=cut

1;
