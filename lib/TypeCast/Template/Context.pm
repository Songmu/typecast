# $Id$
package TypeCast::Template::Context;
use strict;
use warnings;

use base qw( MT::Template::Context );

use TypeCast::ContentModules;
use TypeCast::Util;

my %Global_handlers;

# sub add_tag {
#     my($class, $name, $code) = @_;
#     $Global_handlers{$name} = { code => $code, is_container => 0 };
# }
# sub add_container_tag {
#     my($class, $name, $code) = @_;
#     $Global_handlers{$name} = { code => $code, is_container => 1 };
# }
# sub add_conditional_tag {
#     my $class = shift;

#     while (@_) {
#         my $name = shift || die;
#         my $condition = shift;

#         $Global_handlers{$name} = { code => sub {
#             if ($condition->(@_)) {
#                 return MT::Template::Context::_hdlr_pass_tokens(@_);
#             } else {
#                 my $else = $_[0]->stash('tokens_else');
#                 return '' unless $else && @$else;
#                 return $_[0]->stash('builder')->build($_[0], $else, $_[2]);
#             }
#         }, is_container => 1 };
#     }
#     return;
# }

## init: override handler methods with the same name
# sub init {
#     my $ctx = shift;
#     $ctx->SUPER::init(@_);
#     for my $tag (keys %Global_handlers) {
#         my $arg = $Global_handlers{$tag}{is_container} ?
#             [ $Global_handlers{$tag}{code}, 1 ] : $Global_handlers{$tag}{code};
#         $ctx->register_handler($tag => $arg);
#     }
#     $ctx->register_handler(IncludeModule => \&_hdlr_include_module);
#     $ctx->register_handler(EntryBody => \&_hdlr_entry_body);
#     $ctx->register_handler(ArchiveHeader    => \&_hdlr_archive_header);
#     $ctx;
# }

sub _hdlr_include_module {
    my($ctx, $arg, $cond) = @_;
    my $item = $arg->{module};
    my $rec = TypeCast::ContentModules->cached_module(
        $item,
        MT->current_app->detect_portal,
    ) or return '';
    if ($arg->{uncompiled} && $item ne 'list') {
        return $rec->{uncompiled};
    } else {
        my $b = $ctx->stash('builder');
        defined(my $out = $b->build($ctx, $rec->{compiled}, $cond))
            or return $ctx->error($b->errstr);
        return $out;
    }
}

# sub post_process_handler {
#     sub {
#         my ($ctx, $args, $str) = @_;
#         if (TypePad->current_portal->conf->{typecast}{use_compact_uri}) {
#             $str = TypeCast::Util::make_compact_url($str)
#         }
#         $ctx->SUPER::post_process_handler->($ctx, $args, $str);
#     }
# }

sub _hdlr_archive_header {
    my ($ctx, $arg) = @_;
    my $cat = $ctx->stash('archive_category') or return '';
    return MT->translate('Posts of [_1] category', $cat->label);
}

## for TCOS
sub stash_many {
    my $ctx = shift;
    while (@_) {
        my $key = shift || die;
        $ctx->{__stash}->{$key} = shift;
    }
    $ctx;
}

1;
__END__

=head1 NAME

TypeCast::Template::Context - Template Context for TypeCast

=head1 SYNOPSIS

  use TypeCast::Template::Context;
  TypeCast::Template::Context->add_tag( BlogID => \&BlogID );

  my $ctx  = TypeCast::Template::Context->new;
  my $tmpl = MT::Template->new();
  $tmpl->text($text);
  $tmpl->build($ctx, \%cond);

=head1 DESCRIPTION

TypeCast::Template::Context is a MT::Template::Context replacement for
TypeCast. It allows you to override tag definition only in TypeCast,
which is necessary during the development process where TypePad and
TypeCast run on the same server process.

=cut
