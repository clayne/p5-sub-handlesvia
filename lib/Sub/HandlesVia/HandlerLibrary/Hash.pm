use 5.008;
use strict;
use warnings;

package Sub::HandlesVia::HandlerLibrary::Hash;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.019';

use Sub::HandlesVia::HandlerLibrary;
our @ISA = 'Sub::HandlesVia::HandlerLibrary';

use Sub::HandlesVia::Handler qw( handler );
use Types::Standard qw( HashRef ArrayRef Optional Str CodeRef Item Any Ref Defined );

our @METHODS = qw( all accessor clear count defined delete elements exists get
	is_empty keys kv set shallow_clone values sorted_keys reset
	for_each_key for_each_value for_each_pair );

sub _type_inspector {
	my ($me, $type) = @_;
	if ($type == HashRef or $type == Ref or $type == Ref['HASH']) {
		return {
			trust_mutated => 'always',
		};
	}
	if ($type->is_parameterized and $type->parent->name eq 'HashRef' and $type->parent->library eq 'Types::Standard') {
		return {
			trust_mutated => 'maybe',
			value_type    => $type->type_parameter,
			key_type      => Str,
		};
	}
	if ($type->is_parameterized and $type->parent->name eq 'Map' and $type->parent->library eq 'Types::Standard') {
		return {
			trust_mutated => 'maybe',
			value_type    => $type->parameters->[1],
			key_type      => $type->parameters->[0],
		};
	}
	return $me->SUPER::_type_inspector($type);
}

my $additional_validation_for_set_and_insert = sub {
	my $self = CORE::shift;
	my ($sig_was_checked, $callbacks) = @_;
	my $ti = __PACKAGE__->_type_inspector($callbacks->{isa});
	if ($ti and $ti->{trust_mutated} eq 'always') {
		return ('1;', {});
	}
	if ($ti and $ti->{trust_mutated} eq 'maybe') {
		my $key_coercion   = ($callbacks->{coerce} && $ti->{key_type}->has_coercion);
		my $value_coercion = ($callbacks->{coerce} && $ti->{value_type}->has_coercion);
		my $orig = $callbacks->{'arg'};
		$callbacks->{'arg'} = sub {
			return '$shv_key'   if $_[0]=='1';
			return '$shv_value' if $_[0]=='2';
			goto &$orig;
		};
		return (
			$self->_process_template(sprintf(
				'my($shv_key,$shv_value)=@ARG; if (#ARG>0) { %s }; if (#ARG>1) { %s };',
				$key_coercion
					? '$shv_key=$shv_key_tc->assert_coerce($shv_key)'
					: $ti->{key_type}->inline_assert('$shv_key', '$shv_key_tc'),
				$value_coercion
					? '$shv_value=$shv_value_tc->assert_coerce($shv_value)'
					: $ti->{value_type}->inline_assert('$shv_value', '$shv_value_tc'),
			), %$callbacks),
			{ '$shv_key_tc' => \($ti->{key_type} || Str), '$shv_value_tc' => \$ti->{value_type} },
		);
	}
	return;
};


sub count {
	handler
		name      => 'Hash:count',
		args      => 0,
		template  => 'scalar keys %{$GET}',
		documentation => 'Returns the number of keys in the hash.',
		_examples => sub {
			my ( $class, $attr, $method ) = @_;
			return join "",
				"  my \$object = $class\->new( $attr => { foo => 0, bar => 1 } );\n",
				"  say \$object->$method; ## ==> 2\n",
				"\n";
		},
}

sub is_empty {
	handler
		name      => 'Hash:is_empty',
		args      => 0,
		template  => '!scalar keys %{$GET}',
		documentation => 'Returns true iff there are no keys in the hash.',
		_examples => sub {
			my ( $class, $attr, $method ) = @_;
			return join "",
				"  my \$object = $class\->new( $attr => { foo => 0, bar => 1 } );\n",
				"  say \$object->$method; ## ==> 0\n",
				"  \$object->_set_$attr( {} );\n",
				"  say \$object->$method; ## ==> 1\n",
				"\n";
		},
}

sub keys {
	handler
		name      => 'Hash:keys',
		args      => 0,
		template  => 'keys %{$GET}',
		documentation => 'Returns the list of keys in the hash.',
		_examples => sub {
			my ( $class, $attr, $method ) = @_;
			return join "",
				"  my \$object = $class\->new( $attr => { foo => 0, bar => 1 } );\n",
				"  # says 'foo' and 'bar' in an unpredictable order\n",
				"  say for \$object->$method;\n",
				"\n";
		},
}

sub sorted_keys {
	handler
		name      => 'Hash:sorted_keys',
		args      => 0,
		template  => 'sort(keys %{$GET})',
		documentation => 'Returns an alphabetically sorted list of keys in the hash.',
		_examples => sub {
			my ( $class, $attr, $method ) = @_;
			return join "",
				"  my \$object = $class\->new( $attr => { foo => 0, bar => 1 } );\n",
				"  # says 'bar' then 'foo'\n",
				"  say for \$object->$method;\n",
				"\n";
		},
}

sub values {
	handler
		name      => 'Hash:values',
		args      => 0,
		template  => 'values %{$GET}',
		documentation => 'Returns the list of values in the hash.',
		_examples => sub {
			my ( $class, $attr, $method ) = @_;
			return join "",
				"  my \$object = $class\->new( $attr => { foo => 0, bar => 1 } );\n",
				"  # says '0' and '1' in an unpredictable order\n",
				"  say for \$object->$method;\n",
				"\n";
		},
}

sub all {
	handler
		name      => 'Hash:all',
		args      => 0,
		template  => '%{$GET}',
		documentation => 'Returns the hash in list context.',
		_examples => sub {
			my ( $class, $attr, $method ) = @_;
			return join "",
				"  my \$object = $class\->new( $attr => { foo => 0, bar => 1 } );\n",
				"  my \%hash = \$object->$method;\n",
				"\n";
		},
}

sub elements {
	handler
		name      => 'Hash:elements',
		args      => 0,
		template  => '%{$GET}',
		documentation => 'Returns the hash in list context.',
		_examples => sub {
			my ( $class, $attr, $method ) = @_;
			return join "",
				"  my \$object = $class\->new( $attr => { foo => 0, bar => 1 } );\n",
				"  my \%hash = \$object->$method;\n",
				"\n";
		},
}

sub kv {
	handler
		name      => 'Hash:kv',
		args      => 0,
		template  => 'map [ $_ => ($GET)->{$_} ], keys %{$GET}',
		documentation => 'Returns a list of arrayrefs, where each arrayref is a key-value pair.',
}

sub get {
	handler
		name      => 'Hash:get',
		min_args  => 1,
		usage     => '$key',
		template  => '#ARG>1 ? @{$GET}{@ARG} : ($GET)->{$ARG}',
		documentation => 'Returns a value from the hashref by its key.',
		_examples => sub {
			my ( $class, $attr, $method ) = @_;
			return join "",
				"  my \$object = $class\->new( $attr => { foo => 0, bar => 1 } );\n",
				"  say \$object->$method( 'bar' ); ## ==> 1\n",
				"\n";
		},
}

sub defined {
	handler
		name      => 'Hash:defined',
		args      => 1,
		signature => [Str],
		usage     => '$key',
		template  => 'defined(($GET)->{$ARG})',
		documentation => 'Indicates whether a value exists and is defined in the hashref by its key.',
		_examples => sub {
			my ( $class, $attr, $method ) = @_;
			return join "",
				"  my \$object = $class\->new( $attr => { foo => 0, bar => 1 } );\n",
				"  say \$object->$method( 'foo' ); ## ==> 1\n",
				"\n";
		},
}

sub exists {
	handler
		name      => 'Hash:exists',
		args      => 1,
		signature => [Str],
		usage     => '$key',
		template  => 'defined(($GET)->{$ARG})',
		documentation => 'Indicates whether a value exists in the hashref by its key.',
		_examples => sub {
			my ( $class, $attr, $method ) = @_;
			return join "",
				"  my \$object = $class\->new( $attr => { foo => 0, bar => 1 } );\n",
				"  say \$object->$method( 'foo' ); ## ==> 1\n",
				"  say \$object->$method( 'baz' ); ## ==> 0\n",
				"\n";
		},
}

sub delete {
	handler
		name      => 'Hash:delete',
		min_args  => 1,
		usage     => '$key',
		template  => 'my %shv_tmp = %{$GET}; my @shv_return = delete @shv_tmp{@ARG}; «\%shv_tmp»; wantarray ? @shv_return : $shv_return[-1]',
		lvalue_template  => 'delete(@{$GET}{@ARG})',
		additional_validation => 'no incoming values',
		documentation => 'Removes a value from the hashref by its key.',
		_examples => sub {
			my ( $class, $attr, $method ) = @_;
			return join "",
				"  my \$object = $class\->new( $attr => { foo => 0, bar => 1 } );\n",
				"  \$object->$method( 'foo' );\n",
				"  say exists \$object->$attr\->{foo}; ## ==> 0\n",
				"\n";
		},
}

sub clear {
	handler
		name      => 'Hash:clear',
		args      => 0,
		template  => '«{}»',
		lvalue_template => '%{$GET} = ()',
		additional_validation => 'no incoming values',
		documentation => 'Empties the hash.',
		_examples => sub {
			my ( $class, $attr, $method ) = @_;
			return join "",
				"  my \$object = $class\->new( $attr => { foo => 0, bar => 1 } );\n",
				"  \$object->$method;\n",
				"  say exists \$object->$attr\->{foo}; ## ==> 0\n",
				"  say exists \$object->$attr\->{bar}; ## ==> 0\n",
				"\n";
		},
}

sub shallow_clone {
	handler
		name      => 'Hash:shallow_clone',
		args      => 0,
		template  => '+{%{$GET}}',
		documentation => 'Creates a new hashref with the same keys and values as the original.',
}

sub set {
	my $me = CORE::shift;
	handler
		name      => 'Hash:set',
		min_args  => 2,
		usage     => '$key, $value, ...',
		template  => (
			'my (@shv_params) = @ARG; ' .
			'scalar(@shv_params) % 2 and do { require Carp; Carp::croak("Wrong number of parameters; expected even-sized list of keys and values") };' .
			'my (@shv_keys_idx) = grep(!($_ % 2), 0..$#shv_params); ' .
			'my (@shv_values_idx) = grep(($_ % 2), 0..$#shv_params); ' .
			'grep(!defined, @shv_params[@shv_keys_idx]) and do { require Carp; Carp::croak("Undef did not pass type constraint; keys must be defined") };'.
			'"____VALIDATION_HERE____"; '.
			'my %shv_tmp = %{$GET}; @shv_tmp{@shv_params[@shv_keys_idx]} = @shv_params[@shv_values_idx]; «\\%shv_tmp»;' .
			'wantarray ? @shv_tmp{@shv_params[@shv_keys_idx]} : $shv_tmp{$shv_params[$shv_keys_idx[0]]}' ),
		lvalue_template  => (
			'my (@shv_params) = @ARG; ' .
			'scalar(@shv_params) % 2 and do { require Carp; Carp::croak("Wrong number of parameters; expected even-sized list of keys and values") };' .
			'my (@shv_keys_idx) = grep(!($_ % 2), 0..$#shv_params); ' .
			'my (@shv_values_idx) = grep(($_ % 2), 0..$#shv_params); ' .
			'grep(!defined, @shv_params[@shv_keys_idx]) and do { require Carp; Carp::croak("Undef did not pass type constraint; keys must be defined") };'.
			'"____VALIDATION_HERE____"; '.
			'@{$GET}{@shv_params[@shv_keys_idx]} = @shv_params[@shv_values_idx];' .
			'wantarray ? @{$GET}{@shv_params[@shv_keys_idx]} : ($GET)->{$shv_params[$shv_keys_idx[0]]}' ),
		additional_validation => sub {
			my $self = CORE::shift;
			my ($sig_was_checked, $callbacks) = @_;
			my $ti = __PACKAGE__->_type_inspector($callbacks->{isa});
			if ($ti and $ti->{trust_mutated} eq 'always') {
				# still need to check keys are strings
				return (
					sprintf(
						'for my $shv_tmp (@shv_keys_idx) { %s };',
						Str->inline_assert('$shv_params[$shv_tmp]', '$Types_Standard_Str'),
					),
					{ '$Types_Standard_Str' => \(Str) },
					'LATER!',
				);
			}
			if ($ti and $ti->{trust_mutated} eq 'maybe') {
				my $key_coercion   = ($callbacks->{coerce} && $ti->{key_type}->has_coercion);
				my $value_coercion = ($callbacks->{coerce} && $ti->{value_type}->has_coercion);
				return (
					sprintf(
						'for my $shv_tmp (@shv_keys_idx) { %s }; for my $shv_tmp (@shv_values_idx) { %s };',
						$key_coercion
							? '$shv_params[$shv_tmp] = $shv_key_tc->assert_coerce($shv_params[$shv_tmp])'
							: $ti->{key_type}->inline_assert('$shv_params[$shv_tmp]', '$shv_key_tc'),
						$value_coercion
							? '$shv_params[$shv_tmp] = $shv_value_tc->assert_coerce($shv_params[$shv_tmp])'
							: $ti->{value_type}->inline_assert('$shv_params[$shv_tmp]', '$shv_value_tc'),
					),
					{ '$shv_key_tc' => \($ti->{key_type}), '$shv_value_tc' => \($ti->{value_type}) },
					'LATER!',
				);
			}
			return;
		},
		documentation => 'Given a key and value, adds the key to the hashref with the given value.',
		_examples => sub {
			my ( $class, $attr, $method ) = @_;
			return join "",
				"  my \$object = $class\->new( $attr => { foo => 0, bar => 1 } );\n",
				"  \$object->$method( bar => 2, baz => 1 );\n",
				"  say \$object->$attr\->{foo}; ## ==> 0\n",
				"  say \$object->$attr\->{baz}; ## ==> 1\n",
				"  say \$object->$attr\->{bar}; ## ==> 2\n",
				"\n";
		},
}

sub accessor {
	handler
		name      => 'Hash:accessor',
		min_args  => 1,
		max_args  => 2,
		signature => [Str, Optional[Any]],
		usage     => '$key, $value?',
		template  => 'if (#ARG == 1) { ($GET)->{ $ARG[1] } } else { my %shv_tmp = %{$GET}; $shv_tmp{$ARG[1]} = $ARG[2]; «\\%shv_tmp» }',
		lvalue_template => '(#ARG == 1) ? ($GET)->{ $ARG[1] } : (($GET)->{ $ARG[1] } = $ARG[2])',
		additional_validation => $additional_validation_for_set_and_insert,
		documentation => 'Acts like C<get> if given one argument, or C<set> if given two arguments.',
}

sub for_each_pair {
	handler
		name      => 'Hash:for_each_pair',
		args      => 1,
		signature => [CodeRef],
		usage     => '$coderef',
		template  => 'while (my ($shv_key,$shv_value)=each %{$GET}) { &{$ARG}($shv_key,$shv_value) }; $SELF',
		documentation => 'Chainable method which calls the coderef for each key in the hash, passing the key and value to the coderef.',
}

sub for_each_key {
	handler
		name      => 'Hash:for_each_key',
		args      => 1,
		signature => [CodeRef],
		usage     => '$coderef',
		template  => 'for my $shv_key (keys %{$GET}) { &{$ARG}($shv_key) }; $SELF',
		documentation => 'Chainable method which calls the coderef for each key in the hash, passing just the key to the coderef.',
}

sub for_each_value {
	handler
		name      => 'Hash:for_each_value',
		args      => 1,
		signature => [CodeRef],
		usage     => '$coderef',
		template  => 'for my $shv_value (values %{$GET}) { &{$ARG}($shv_value) }; $SELF',
		documentation => 'Chainable method which calls the coderef for each value in the hash, passing just the value to the coderef.',
}

sub reset {
	handler
		name      => 'Hash:reset',
		args      => 0,
		template  => '« $DEFAULT »',
		default_for_reset => sub { '{}' },
		documentation => 'Resets the attribute to its default value, or an empty hashref if it has no default.',
}

1;
