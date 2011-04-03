package inc::DiffMakeMaker;

use Moose;

extends 'Dist::Zilla::Plugin::MakeMaker::Awesome';
    
override _build_WriteMakefile_args => sub { +{
    # Add LIBS => to WriteMakefile() args
    %{ super() },
    LIBS => [''],
    INC => '-I.',
    OBJECT => '$(O_FILES)', # link all the C files too
    
} };

__PACKAGE__->meta->make_immutable;
