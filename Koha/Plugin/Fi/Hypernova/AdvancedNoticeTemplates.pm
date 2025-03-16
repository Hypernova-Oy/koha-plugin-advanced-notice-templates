package Koha::Plugin::Fi::Hypernova::AdvancedNoticeTemplates;

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# This program comes with ABSOLUTELY NO WARRANTY;

use Modern::Perl;

use base qw(Koha::Plugins::Base);

use File::Basename;
use MARC::File::XML;
use MARC::Record;
use Mojo::JSON qw(encode_json decode_json);
use YAML::XS;
use Try::Tiny;

use C4::Languages;

our $VERSION = "24.11.01.0";

our $metadata = {
    name            => 'Advanced Notice Templates',
    author          => 'Lari Taskula',
    date_authored   => '2025-04-17',
    date_updated    => "2025-04-17",
    minimum_version => '24.11.01.000',
    maximum_version => undef,
    version         => $VERSION,
    description     =>
        "This plugin provides advanced management to notice templates, including one-click setting defaults in a multilingual environment.",
};

sub new {
    my ( $class, $args ) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual $self
    my $self = $class->SUPER::new($args);
    $self->{cgi} = CGI->new();

    return $self;
}

sub add_header_and_footer {
    my ( $self, $params ) = @_;

    my $content = $params->{'content'};
    my $lang    = $params->{'lang'};
    my $mtt     = $params->{'message_transport_type'};

    my $hasexception = sub {
        my ($headerorfooter) = @_;
        if ( $params->{'code'} ) {
            my $exception = $self->retrieve_data( $lang . "_" . $mtt . "_" . $headerorfooter . "_exception" );
            return 0 unless $exception;

            return 1 if grep { $_ eq $params->{'code'} } split( /,/, $exception );
        }
        return 0;
    };

    my $header = $self->retrieve_data( $lang . "_" . $mtt . "_header" );
    my $footer = $self->retrieve_data( $lang . "_" . $mtt . "_footer" );
    $content = $header . "\r\n" . $content if $header && !&$hasexception('header');
    $content = $content . "\r\n" . $footer if $footer && !&$hasexception('footer');

    return $content;
}

sub api_namespace {
    my ($self) = @_;

    return 'advanced-notice-templates';
}

sub api_routes {
    my ( $self, $args ) = @_;

    my $spec_str = $self->mbf_read('openapi.json');
    my $spec     = decode_json($spec_str);

    return $spec;
}

sub configure {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    my $all_languages = $self->_get_all_languages;

    my @mtts = map { $_->message_transport_type } Koha::Patron::MessagePreference::Transport::Types->search->as_list;

    unless ( $cgi->param('save') ) {
        my $template         = $self->get_template( { file => 'configure.tt' } );
        my $default_language = $self->retrieve_data('default_language') || 'en';
        my @languages;
        foreach my $mtt (@mtts) {
            $template->param( 'use_html_' . $mtt => 1 ) if $self->retrieve_data( 'use_html_' . $mtt );
            $template->param(
                'use_html_' . $mtt . '_exception' => $self->retrieve_data( 'use_html_' . $mtt . '_exception' ) );
            $template->param( 'use_anonymous_' . $mtt => 1 ) if $self->retrieve_data( 'use_anonymous_' . $mtt );
            $template->param( 'use_anonymous_'
                    . $mtt
                    . '_exception' => $self->retrieve_data( 'use_anonymous_' . $mtt . '_exception' ) );
            foreach my $lang (@$all_languages) {
                $template->param(
                    $lang->{'rfc4646_subtag'}
                        . "_${mtt}_footer" => $self->retrieve_data( $lang->{'rfc4646_subtag'} . "_${mtt}_footer" ),
                    $lang->{'rfc4646_subtag'}
                        . "_${mtt}_footer_exception" =>
                        $self->retrieve_data( $lang->{'rfc4646_subtag'} . "_${mtt}_footer_exception" ),
                    $lang->{'rfc4646_subtag'}
                        . "_${mtt}_header" => $self->retrieve_data( $lang->{'rfc4646_subtag'} . "_${mtt}_header" ),
                    $lang->{'rfc4646_subtag'}
                        . "_${mtt}_header_exception" =>
                        $self->retrieve_data( $lang->{'rfc4646_subtag'} . "_${mtt}_header_exception" )
                );
            }
        }

        $template->param(
            default_language => $default_language,
            mtts             => \@mtts,
            notice_languages => $all_languages,
        );

        $self->output_html( $template->output() );
    } else {

        my $clean_exceptions = sub {
            my ($str) = @_;
            return "" unless $str;
            $str =~ s/[\s\t]//g;
            $str =~ s/[\|]/,/g;
            $str =~ s/,+/,/g;

            $str = join( ',', List::MoreUtils::uniq( split( /,/, $str ) ) );
            return $str;
        };

        my $store_data = { default_language => $cgi->param('default_language') };
        foreach my $mtt (@mtts) {
            $store_data->{ 'use_html_' . $mtt } = $cgi->param( 'use_html_' . $mtt ) ? 1 : 0;
            $store_data->{ 'use_html_' . $mtt . '_exception' } =
                &$clean_exceptions( $cgi->param( 'use_html_' . $mtt . '_exception' ) );
            $store_data->{ 'use_anonymous_' . $mtt } = $cgi->param( 'use_anonymous_' . $mtt ) ? 1 : 0;
            $store_data->{ 'use_anonymous_' . $mtt . '_exception' } =
                &$clean_exceptions( $cgi->param( 'use_anonymous_' . $mtt . '_exception' ) );
            foreach my $lang (@$all_languages) {
                my $footer_exception =
                    &$clean_exceptions( $cgi->param( $lang->{'rfc4646_subtag'} . "_${mtt}_footer_exception" ) );
                my $header_exception =
                    &$clean_exceptions( $cgi->param( $lang->{'rfc4646_subtag'} . "_${mtt}_header_exception" ) );
                $store_data->{ $lang->{'rfc4646_subtag'} . "_${mtt}_footer" } =
                    $cgi->param( $lang->{'rfc4646_subtag'} . "_${mtt}_footer" );
                $store_data->{ $lang->{'rfc4646_subtag'} . "_${mtt}_footer_exception" } = $footer_exception;
                $store_data->{ $lang->{'rfc4646_subtag'} . "_${mtt}_header" } =
                    $cgi->param( $lang->{'rfc4646_subtag'} . "_${mtt}_header" );
                $store_data->{ $lang->{'rfc4646_subtag'} . "_${mtt}_header_exception" } = $header_exception;
            }
        }
        $self->store_data($store_data);
        $self->go_home();
    }
}

sub freeze_template {
    my ( $self, $template, $freeze ) = @_;

    my $frozen_templates_str = $self->retrieve_data('frozen_templates') || '';
    my @frozen_templates     = split( /,/, $frozen_templates_str );

    my $identifier          = $self->_template_identifier($template);
    my $is_currently_frozen = $self->is_frozen_template($template);
    unless ( defined $freeze ) {
        return $is_currently_frozen;
    }
    if ($freeze) {
        unless ($is_currently_frozen) {
            push( @frozen_templates, $identifier );
            $frozen_templates_str = join( ',', @frozen_templates );
            $self->store_data( { frozen_templates => $frozen_templates_str } );
        }
        return 1;
    } else {
        if ($is_currently_frozen) {
            @frozen_templates     = grep { $_ ne $identifier } @frozen_templates;
            $frozen_templates_str = join( ',', @frozen_templates );
            $self->store_data( { frozen_templates => $frozen_templates_str } );
        }
        return 0;
    }
}

=head3 generate_default_plugin_templates

Generates plugin templates from Koha's default templates.

NOTE! This will overwrite existing plugin templates. Use with care and only in a version controlled environment.

=cut

sub generate_default_plugin_templates {
    my ( $self, $params ) = @_;

    my $dbms = C4::Context->config("db_scheme") ? C4::Context->config("db_scheme") : "mysql";
    my $templates;

    my $modified_counter = 0;

    my $all_languages = $self->_get_all_languages;
    foreach my $lang (@$all_languages) {
        my $lang_dir = $lang->{'rfc4646_subtag'};
        my $template_koha_path =
            C4::Context->config('intranetdir') . "/installer/data/$dbms/$lang_dir/mandatory/sample_notices.yml";
        my $template_plugin_path = $self->mbf_dir() . "/notice_templates/$lang_dir/";
        my $yaml                 = YAML::XS::LoadFile($template_koha_path);
        my $letters              = $yaml->{'tables'}->[0]->{'letter'}->{'rows'};
        my $plugin_templates;
        foreach my $template (@$letters) {
            my $content = join "\r\n", @{ $template->{'content'} };
            $plugin_templates->{ $template->{'code'} }->{'name'}   = $template->{'name'};
            $plugin_templates->{ $template->{'code'} }->{'module'} = $template->{'module'};
            my $html = $self->get_content_type_key( $template->{'is_html'} );
            $plugin_templates->{ $template->{'code'} }->{'template'}->{ $template->{'message_transport_type'} }->{$html}
                = {
                $self->get_anonymous_template_key(1) => {
                    content => $content,
                    title   => $template->{'title'},
                },
                $self->get_anonymous_template_key(0) => {
                    content => $content,
                    title   => $template->{'title'},
                },
                };
        }
        foreach my $letter_code ( keys %$plugin_templates ) {
            mkdir($template_plugin_path);
            if ( !$params->{'overwrite'} && -e $template_plugin_path . "$letter_code.yml" ) {
                warn $template_plugin_path . "$letter_code.yml already exists. Not overwriting.";
                next;
            }
            open my $fh, '>>', $template_plugin_path . "$letter_code.yml";
            close $fh;
            $self->_write_template_to_disk(
                $template_plugin_path . "$letter_code.yml",
                $plugin_templates->{$letter_code}
            );
            $modified_counter++;
        }
    }

    return $modified_counter;
}

=head3 get_anonymous_template_key

=cut

sub get_anonymous_template_key {
    my ( $self, $is_anonymous ) = @_;
    return $is_anonymous ? 'anonymous' : 'default';
}

=head3 get_content_type_key

=cut

sub get_content_type_key {
    my ( $self, $is_html ) = @_;
    return $is_html ? 'html' : 'plain';
}

=head3 get_modifiable_templates

Loads notice templates from disk and compares them to the ones defined in database.

If a template in the database does not match the template on the disk, it is
considered "modifiable" and returned by this method.

Returns a HASHref in the following format:

{
    $letter_code => [
        {
            lang => rfc4646 language (exception en, default),
            code => letter.code,
            message_transport_type => letter.message_transport_type,
            module                 => letter.module,
            name                   => letter.name,
            is_html                => letter.is_html,
            new_template => {
                title   => "title from the plugin's template repository"
                content => "content from the plugin's template repository"
            },
            old_template => {
                title   => "title from the Koha database"
                content => "content from the Koha database"
            }
        },
        {
            lang => same notice template but for another language...
        },
        ...
    ],
    $letter_code2 => [{},{},{},...],
    $letter_code3 => [...]
}

=cut

sub get_modifiable_templates {
    my ( $self, $params ) = @_;

    my $branchcode   = $params->{'branchcode'}   // '';
    my $letter_codes = $params->{'letter_codes'} // [];
    my $module       = $params->{'module'}       // { -like => '%' };

    my $plugin_templates = $params->{'plugin_templates'} // $self->load_default_plugin_templates(
        {
            letter_codes => $letter_codes,
        }
    );

    return unless $plugin_templates;

    my $default_language = $self->retrieve_data('default_language') || 'en';
    $default_language = 'en' unless exists $plugin_templates->{$default_language};

    my $retrieved_data;
    my $modifiable_templates;
    foreach my $lang ( keys %$plugin_templates ) {
        my $is_default_language = $default_language eq $lang;
        foreach my $letter_code ( @$letter_codes ? @$letter_codes : keys %{ $plugin_templates->{$lang} } ) {
            my @modifiable_templates_this_code;
            my $template_name = $plugin_templates->{$default_language}->{$letter_code}->{'name'};

            foreach my $mtt ( keys %{ $plugin_templates->{$lang}->{$letter_code}->{'template'} } ) {

                # avoid having to re-retrieve data on each iteration
                my $retrieve_data = sub {
                    my ($retrieve_key) = @_;
                    my $retrieve_key_exception = "${retrieve_key}_exception";
                    my $retrieve_data;
                    if ( exists $retrieved_data->{$retrieve_key} ) {
                        $retrieve_data = $retrieved_data->{$retrieve_key} ? 1 : 0;
                    } else {
                        $retrieve_data = $retrieved_data->{$retrieve_key} = $self->retrieve_data($retrieve_key) ? 1 : 0;
                    }
                    unless ( exists $retrieved_data->{$retrieve_key_exception} ) {
                        $retrieved_data->{$retrieve_key_exception} =
                            $self->retrieve_data($retrieve_key_exception) ? 1 : 0;
                    }
                    return !$retrieve_data
                        if $retrieved_data->{$retrieve_key_exception} && grep { $_ eq $letter_code }
                        split( /,/, $retrieved_data->{$retrieve_key_exception} );
                    return $retrieve_data;
                };

                my $is_html      = &$retrieve_data("use_html_$mtt");
                my $is_anonymous = &$retrieve_data("use_anonymous_$mtt");

                my $content_type_key = $self->get_content_type_key($is_html);
                unless ( exists $plugin_templates->{$lang}->{$letter_code}->{'template'}->{$mtt}->{$content_type_key} )
                {
                    # this content type does not exist, attempt to use the other one instead
                    $is_html = !$is_html;
                    $content_type_key = $self->get_content_type_key( $is_html );
                    next
                        unless
                        exists $plugin_templates->{$lang}->{$letter_code}->{'template'}->{$mtt}->{$content_type_key};
                }

                my $anonymous_template_key = $self->get_anonymous_template_key($is_anonymous);

                # if non-anonymous template is requested but it does not exist, try using anonymous template
                if (   !$is_anonymous
                    && !
                    exists $plugin_templates->{$lang}->{$letter_code}->{'template'}->{$mtt}->{$content_type_key}
                    ->{$anonymous_template_key} )
                {
                    $anonymous_template_key = $self->get_anonymous_template_key( !$is_anonymous );
                }
                next
                    unless exists $plugin_templates->{$lang}->{$letter_code}->{'template'}->{$mtt}->{$content_type_key}
                    ->{$anonymous_template_key};

                my $plugin_template =
                    $plugin_templates->{$lang}->{$letter_code}->{'template'}->{$mtt}->{$content_type_key}
                    ->{$anonymous_template_key};
                $plugin_template->{'content'} = $self->add_header_and_footer(
                    {
                        code                   => $letter_code,
                        content                => $plugin_template->{'content'},
                        message_transport_type => $mtt,
                        lang                   => $lang,
                    }
                );

                foreach my $current_language ( @{ $is_default_language ? [ 'default', $lang ] : [$lang] } ) {
                    my $current_template = Koha::Notice::Templates->find(
                        {
                            branchcode             => $branchcode,
                            lang                   => $current_language,
                            code                   => $letter_code,
                            message_transport_type => $mtt,
                            module                 => $module,
                        }
                    );

                    if (
                        ( !$branchcode && !$current_template )
                        || (
                            $current_template
                            && (   $current_template->content ne $plugin_template->{'content'}
                                || $current_template->title ne $plugin_template->{'title'}
                                || $current_template->name ne $template_name )
                        )
                        )
                    {
                        push(
                            @{ $modifiable_templates->{$letter_code} },
                            {
                                lang => $current_template ? $current_template->lang : $current_language,
                                code => $letter_code,
                                message_transport_type => $mtt,
                                module                 => $plugin_templates->{$lang}->{$letter_code}->{'module'},
                                name                   => $template_name,
                                frozen                 => $self->is_frozen_template(
                                    {
                                        code => $letter_code,
                                        lang => $current_template ? $current_template->lang : $current_language,
                                        message_transport_type => $mtt
                                    }
                                ),
                                is_html      => $is_html,
                                new_template => $plugin_templates->{$lang}->{$letter_code}->{'template'}->{$mtt}
                                    ->{$content_type_key}->{$anonymous_template_key},
                                old_template => {
                                    title   => $current_template ? $current_template->title   : '',
                                    content => $current_template ? $current_template->content : '',
                                }
                            }
                        );
                    }
                }
            }
        }
    }

    my $sorted_modifiable_templates;
    foreach my $letter_code ( keys %$modifiable_templates ) {
        my @sorted_templates = sort { $a->{'lang'} cmp $b->{'lang'} } @{ $modifiable_templates->{$letter_code} };
        $sorted_modifiable_templates->{$letter_code} = \@sorted_templates;
    }
    return $sorted_modifiable_templates;
}

sub install {
    my ($self) = @_;

    unless ( $self->retrieve_data('use_anonymous_templates') ) {
        $self->store_data( { use_anonymous_templates => 1 } );
    }

    unless ( $self->retrieve_data('use_html_email') ) {
        $self->store_data( { use_html_email => 1 } );
    }

    return 1;
}

sub intranet_js {
    my ($self)      = @_;
    my $cgi         = $self->{'cgi'};
    my $script_name = $cgi->script_name;

    if ( $script_name =~ /tools\/letter\.pl/ ) {
        my $templates = $self->load_default_plugin_templates;

        my @letter_codes;
        foreach my $letter_code ( keys %{ $templates->{ $self->retrieve_data('default_language') } } ) {
            push( @letter_codes, $letter_code );
        }

        my $letter_codes_str = encode_json \@letter_codes;
        my $modal1           = $self->mbf_read('html/modal1.html');
        my $js               = $self->mbf_read('js/letter.js');
        my $css              = $self->mbf_read('css/ant.css');
        my $diffdotjs        = $self->get_plugin_http_path() . '/js/diff.js';
        $js =~ s/__ANT_PLUGIN_MODAL1__/$modal1/;
        $js =~ s/__ANT_PLUGIN_TEMPLATES__/$letter_codes_str/g;
        return
            "<script src=\"$diffdotjs\"></script>\n<script>\n$js\n</script><style type=\"text/css\">\n$css\n</style>";
    }
}

sub is_frozen_template {
    my ( $self, $template ) = @_;
    my $frozen_templates_str = $self->retrieve_data('frozen_templates') || '';
    my @frozen_templates     = split( /,/, $frozen_templates_str );

    my $identifier          = $self->_template_identifier($template);
    my $is_currently_frozen = grep { $_ eq $identifier } @frozen_templates;

    return $is_currently_frozen ? 1 : 0;
}

=head3 load_default_plugin_templates

Loads default notice templates provided by this plugin.

$self->load_default_plugin_templates($params);

$params:
  lang => ARRAYref of rfc4646 (e.g. en, fi-FI, sv-SE) languages. If not provided, all installed languages will be loaded
  letter_codes => ARRAYref of Koha letter.letter_code. If not provided, all letter codes will be loaded

Returns notice templates in a HASHref.

=cut

sub load_default_plugin_templates {
    my ( $self, $params ) = @_;

    my $dbms = C4::Context->config("db_scheme") ? C4::Context->config("db_scheme") : "mysql";
    my $templates;

    my $languages;
    if ( $params->{'lang'} ) {
        $languages = $params->{'lang'};
    } else {
        $languages = $self->_get_all_languages;
    }

    foreach my $lang (@$languages) {
        my $lang_dir = ref($lang) eq 'HASH' ? $lang->{'rfc4646_subtag'} : $lang;
        my $path     = my $template_plugin_path = $self->mbf_dir() . "/notice_templates/$lang_dir/";

        if ( $params->{'letter_codes'} && @{ $params->{'letter_codes'} } ) {
            foreach my $letter_code ( @{ $params->{'letter_codes'} } ) {
                my $yaml = YAML::XS::LoadFile( $path . "$letter_code.yml" );
                $templates->{$lang_dir}->{$letter_code}->{'module'}   = $yaml->{'module'};
                $templates->{$lang_dir}->{$letter_code}->{'name'}     = $yaml->{'name'};
                $templates->{$lang_dir}->{$letter_code}->{'template'} = $yaml->{'template'};
            }
        } else {
            foreach my $template_filepath ( glob( $path . '*.yml' ) ) {
                my $letter_code = File::Basename::basename( $template_filepath, ".yml" );
                my $yaml        = eval { YAML::XS::LoadFile($template_filepath); };
                if ($@) {
                    warn $template_filepath;
                    die $@;
                }
                $templates->{$lang_dir}->{$letter_code}->{'module'}   = $yaml->{'module'};
                $templates->{$lang_dir}->{$letter_code}->{'name'}     = $yaml->{'name'};
                $templates->{$lang_dir}->{$letter_code}->{'template'} = $yaml->{'template'};
            }
        }
    }

    return $templates;
}

=head3 store_plugin_templates

Stores notice templates provided by this plugin to Koha's database.

Params format defined by this plugin's openapi.json path "/templates/modifiable" POST request body parameter.

=cut

sub store_plugin_templates {
    my ( $self, $params ) = @_;

    my $templates = $params->{'templates'};

    my $modifiable_templates = $self->get_modifiable_templates();

    my @templates_not_found;
    my @templates_found;

    foreach my $template_to_modify (@$templates) {
        my $found_template;
        foreach my $template ( @{ $modifiable_templates->{ $template_to_modify->{'code'} } } ) {
            if (
                   $template->{'lang'} eq $template_to_modify->{'lang'}
                && $template->{'message_transport_type'} eq $template_to_modify->{'message_transport_type'}
                && (  !$template_to_modify->{'module'}
                    || $template_to_modify->{'module'} && ( $template->{'module'} eq $template_to_modify->{'module'} ) )
                )
            {
                my $branchcode;

                if ( $template_to_modify->{'branchcode'} ) {
                    $branchcode = Koha::Libraries->find( $template_to_modify->{'branchcode'} )->branchcode;
                    next unless $branchcode;
                } else {
                    $branchcode = '';
                }

                $found_template = $template_to_modify;
                my $existing_template = Koha::Notice::Templates->find(
                    {
                        branchcode             => $branchcode,
                        code                   => $template->{'code'},
                        lang                   => $template->{'lang'},
                        message_transport_type => $template->{'message_transport_type'},
                        module                 => $template->{'module'},
                    }
                );

                unless ( $found_template->{'do_not_modify'} ) {
                    if ($existing_template) {
                        $existing_template->set(
                            {
                                content => $template->{'new_template'}->{'content'},
                                title   => $template->{'new_template'}->{'title'},
                                name    => $template->{'name'},
                                is_html => $template->{'is_html'} ? 1 : 0,
                            }
                        )->store;
                    } else {
                        Koha::Notice::Template->new(
                            {
                                branchcode             => $branchcode,
                                code                   => $template->{'code'},
                                lang                   => $template->{'lang'},
                                message_transport_type => $template->{'message_transport_type'},
                                module                 => $template->{'module'},
                                content                => $template->{'new_template'}->{'content'},
                                title                  => $template->{'new_template'}->{'title'},
                                name                   => $template->{'name'},
                                is_html                => $template->{'is_html'} ? 1 : 0,
                            }
                        )->store;
                    }
                }

                $self->freeze_template(
                    {
                        code                   => $template->{'code'},
                        lang                   => $template->{'lang'},
                        message_transport_type => $template->{'message_transport_type'}
                    },
                    $found_template->{'freeze'}
                );
                last;
            }
        }
        if ($found_template) {
            push( @templates_found, $found_template );
        } else {
            push( @templates_not_found, $template_to_modify );
        }
    }

    return ( \@templates_found, \@templates_not_found );
}

sub uninstall {
    my ($self) = @_;

    return 1;
}

sub _get_all_languages {
    my ($self) = @_;

    return C4::Languages::getTranslatedLanguages('opac');
}

sub _template_identifier {
    my ( $self, $template ) = @_;

    return $template->{'code'} . '_' . $template->{'lang'} . '_' . $template->{'message_transport_type'};
}

sub _write_template_to_disk {
    my ( $self, $path, $template ) = @_;

    YAML::XS::DumpFile( $path, $template );
}
1;
