#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <mba/diff.h>
#include <mba/allocator.h>

// For the index function, the input is an AV
SV * _diff_idx_fn(AV *s, I32 idx, SV *context) {
	//printf("_diff_idx_fn: array:  %"UVxf" \n", PTR2UV(s));
	//printf("_diff_idx_fn: offset: %d \n", idx);
	SV **value = av_fetch(s, idx, 0);
	if (value == NULL) {
		croak("Internal error...\n") ;
	} else {
		return *value;
	}
}

int _diff_cmp_fn(SV *object1, SV *object2, SV *context) {
	int compared;
	
	//PerlIO_printf(PerlIO_stderr(), "_diff_cmp_fn: called \n");
	//PerlIO_printf(PerlIO_stderr(), "Arg1: %s\n", SvPV_nolen(object1));
	//PerlIO_printf(PerlIO_stderr(), "Arg2: %s\n", SvPV_nolen(object2));
		
	if (SvIOK(object1) && SvIOK(object2)) {
		compared = ! (SvIV(object1) == SvIV(object2));
		//PerlIO_printf(PerlIO_stderr(), "Fast integer compare\n");
		//printf("Arg1: %d\n", SvIV(object1));
		//printf("Arg2: %d\n", SvIV(object2));
		//printf("_diff_cmp_fn returned: %d\n", compared);
		return compared;
	} else if (SvPOK(object1) && SvPOK(object2)) {
		//PerlIO_printf(PerlIO_stderr(), "Fast string compare\n");
		compared = ! sv_eq(object1, object2);
		//printf("_diff_cmp_fn returned: %d\n", compared);
		return compared;
	} 
	
	//PerlIO_printf(PerlIO_stderr(), "_diff_cmp_fn: callback code \n");
	
	croak("Tried to compare non-integer or string values");
    
	return compared;
}

MODULE = Algorithm::Diff::Fast		PACKAGE = Algorithm::Diff::Fast		

AV *
_diff_internal(array1, array2)
		AV *	array1
		AV *	array2
		
	CODE:
		int array1_length = av_len(array1) + 1;
		int array2_length = av_len(array2) + 1;
		int edit_count = 0;
		struct varray *ses;
		AV *result;
		AV *element;
		
		ses = varray_new(sizeof(struct diff_edit), stdlib_allocator);
		
		//PerlIO_printf(PerlIO_stderr(), "diff called s1=%d, s2=%d\n", array1_length, array2_length);
		RETVAL = diff(array1, 0, array1_length, array2, 0, array2_length, 
		              (idx_fn) &_diff_idx_fn, (cmp_fn) &_diff_cmp_fn, 
		              NULL, 0, ses, &edit_count, NULL);
		//PerlIO_printf(PerlIO_stderr(), "diff returned OK!\n");
		//PerlIO_printf(PerlIO_stderr(), "Edit count: %d\n", edit_count);
		
		result = newAV();

		iter_t iterator;
		varray_iterate(ses, &iterator);
		struct diff_edit *next;
		int i = 0;
		while(next = varray_next(ses, &iterator)) {
		    if (next->op == 0) break;
			element = newAV();
		    //PerlIO_printf(PerlIO_stderr(), "Op =  %d\n", next->op);
		    //PerlIO_printf(PerlIO_stderr(), "Off = %d\n", next->off);
		    //PerlIO_printf(PerlIO_stderr(), "Len = %d\n", next->len);
			av_push(element, newSViv(next->op));
			av_push(element, newSViv(next->off));
			av_push(element, newSViv(next->len));
			av_push(result, newRV_inc((SV*) element));
		}
		
		varray_del(ses);
		
		RETVAL = result;
		sv_2mortal((SV*)RETVAL);
		
		// Handling the result is going to be fun!
		
	OUTPUT:
		RETVAL

