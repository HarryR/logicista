---
layout: post
title:  Beautiful C API Design
date:   2014-02-10 00:00:00
categories: [api, abstraction, programming, design, analysis, modular]
coverimage: /img/posts/cabbage.jpg
covertitle: Cabbage Macro by Danny Nicholson
---

APIs are a language programmers use to simplify and encapsulate abstractions and enable the re-use code, but given the fundamental nature of the C ABI and it's limitations there are additional layers of design criteria which must be considered if the API is to stand the test of time.

If you come from the school of thought that code should be self documenting, or at least the API must be structured in a way which encourages correct usage and appreciate the value of correctly and obviously naming the abstractions then you are on the right tracks, it can be considered an art form and also a pragmatic achievement.

What are the absolute basics that can be universally agreed on, regardless of which language the API is written in?

 * Be consistent
 * Only expose neatly encapsulated abstractions
 * Usage should be obvious to practitioners
 * Naming must be meaningful but terse

However with C and other natively compiled languages there are other aspects which must be contended with like namely platform calling conventions, compiler semantics, the ABI and kernel system call interface. The limitations imposed aren't unique to C, but they do distinctively shape the way programs are written and the qualities which are thought as being 'beautiful'.

In the old-school days of UNIX the standard C runtime was statically compiled into every application leaving kernel's system call interface remained as the first point of separation of concern and the primary API for all applications, because of this it seems like a logical place to start.


## TL;DR

 * Consistently naming abstractions is hard, think about it.
 * Make sure the header files are clean ANSI C
 * Learn what const-correctness is
 * Use logical ordering when naming things
 * Only expose scalar types and opaque pointers 
 * Make it clear about who manages memory
 * Be aware of scripting languages using the C library


## UNIX System Calls

The anatomy of a system call is quite simple, the program moves system call arguments into registers and invokes an interrupt which transfers control to the kernel, this implicitly limits arguments and the return value to the size of individual registers, typically 32 or 64bits wide on todays architectures, and means the calling side can't (and shouldn't) access kernel structures directly and the kernel doesn't return pointers to new data in user-space unless the caller has specified the address and size of the return area.

The C standard library provides definitions and wrappers for these system calls and common practice in type choices and names make their use obvious to people well versed in C.

A good example is the file I/O functions which could be considered object orientated given that file handles are objects and functions which operate on them take the file handle as the first argument.

```c
int stat(const char *path, struct stat *buf); 
int open(const char *pathname, int flags, mode_t mode); 
int accept(int sockfd, struct sockaddr *addr, socklen_t *addrlen);
ssize_t read(int fd, void *buf, size_t count); 
int close(int fd); 
```

Rules that can be devised from this are:

 * Names are easily understood operations
 * Parameters which aren't modified are passed as `const`
 * Signed return values indicate `n < 0` as an error code
 * Opaque handles (file descriptors) are used
 * When memory is modifiable the length usually accompanies it

An exercise for the reader could be to find standard C system calls on UNIX and Windows systems which are badly designed.


## What about libraries?

Three excellent examples of well designed libraries are frequently brought up in discussions: [POSIX threads](http://pubs.opengroup.org/onlinepubs/7908799/xsh/pthread.h.html), [SQLite](http://www.sqlite.org/capi3ref.html) and [ØMQ](http://api.zeromq.org/).

They use predictable naming conventions, opaque pointers for types and neatly abstract the functionality which makes remembering the functions surprisingly easy and unambiguous for people reading the code.

Common questions for library writers include:

 * Who owns the memory?
 * What are the standard naming conventions?
 * Which types should be opaque?

ØMQ and POSIX threads take very similar approaches both in naming and structure as you can see below. ØMQ uses `void*` for opaque pointers which are managed by the library and `zmq_xxx_t` types that the caller must allocate.

The POSIX threads API doesn't have any functions which return newly allocated memory, but treats all types as opaque and discourages you from needing to know what it's structures contain by providing a well thought out set of functions to manipulate them.

```c
/* ØMQ Message interface */
int zmq_msg_init (zmq_msg_t *msg);
int zmq_msg_set (zmq_msg_t *message, int property, int value);
int zmq_msg_close (zmq_msg_t *msg);

/* ØMQ Context interface */
void *zmq_ctx_new ();
int zmq_ctx_set (void *context, int option_name, int option_value);
int zmq_ctx_destroy (void *context);
```

Even then the `zmq_msg_t` type is opaque apart from the number of bytes required to store it:

```c
typedef struct zmq_msg_t {unsigned char _ [40];} zmq_msg_t;
```

One thing that disappointed me is that the ØMQ library doesn't use `const` tagging for anything apart from strings passed in as arguments and error message descriptions returned from `zmq_strerror`. It would be expected that `zmq_ctx_get` and `zmq_msg_more` would take a `const` type as the first parameter.


## Pure Functions and Constant Parameters

While C isn't a functional language there are idioms which affect code generation and behavior of the type system such as [idempotence](http://en.wikipedia.org/wiki/Idempotence), [pure functions](http://en.wikipedia.org/wiki/Pure_function), [side effects](http://en.wikipedia.org/wiki/Side_effect_\(computer_science\)), [mutability](http://en.wikipedia.org/wiki/Immutable_object) of types and [const-correctness](http://en.wikipedia.org/wiki/Const-correctness).

The const-correctness Wikipedia article provides examples of all types of constant pointers, the more important point is the constraints introduced into the type system which propagate in both directions from the function definition.

Applying `const` to arguments and return values also reinforces naming choices and reduces ambiguity or at least reduces the number of possible things which could be happening with a given choice of words, such connotations are:

 * `new` and `create` - Allocate memory, return mutable pointer
 * `init` - Initialize mutable memory
 * `read` and `write` - Has side effects, usually mutable
 * `get` - Should have no side effects, can return `const`
 * `set` - Mutable with no side effects, usually accepts `const`
 * `free` - Free allocated memory, mutable with side effects
 * `destroy` - Tear-down a structure where caller owns memory

A good example of conflicting naming versus parameter types would be the difference between `set` and `get` operations and how `const` affects their interpretation:

```c
char *derp_get_property (derp_o *widget, char *name);
void derp_set_property (derp_o *widget, char *name, char *value);
```

To ensure that memory ownership is explicitly defined by restricting side-effects and mutability it should probably be declared as:

```c
const char *derp_get_property (const derp_o *widget, const char *name);
void derp_set_property (derp_o *widget, const char *name, const char *value);
```

Specifying `const` on all parameters means you you don't own the memory returned by the function, you cannot modify it and need to be careful if you perform calls with side effects after getting the property. It also means that the function will not modify the `derp_o` widget and will not keep a reference to `name` beyond the scope of the function call.

## Naming Conventions: `CamelCase` vs `lower_case`

There is a distinct difference in naming conventions used on the Windows operating system and older libraries compared to modern libraries and common practices in general, I would be tempted to call the latter 'modern C' because it better represents a refinement and progression towards easier to read code, this is even present in the [C11](http://www.drdobbs.com/cpp/c-finally-gets-a-new-standard/232800444) standard. 

Modern C has the de facto standard of hierarchical abstractions separated by underscores in the Microsoft C world and old libraries like Motif there is an abundance of `CamelCase` with a literal-english naming scheme that makes it harder to remember what function names are going to be or to use auto-complete for hints.

The mental model used for memorizing functions and abstractions becomes clouded when many different modules share the same keyword at the start or have inconsistent keyword ordering for the same operation in different modules.

Motif was a widely used library with naming a mix of naming conventions which generally make sense especially for such a large codebase doing object orientated UI tasks in C, but it quickly gets tedious to remember the different idioms used for naming:

 * `Widget XmCreateComboBox (...);`
 * `Widget XmVaCreateManagedComboBox (...);`
 * `void XmComboBoxSelectItem (...);`
 * `XmComboBoxCallbackStruct *cb = mycallback;`
 * `XtSetArg(arg, XmNcomboBoxType, XmCOMBO_BOX);`

The GTK+ library in comparison exudes thoughtfulness in regards to modern C naming conventions:

 * `GtkWidget* gtk_combo_box_new (...);`
 * `gchar* gtk_combo_box_get_active_text (...);`
 * `gint gtk_combo_box_get_active (...);`
 * `g_signal_connect(G_OBJECT(combo), "changed", ...);`

The structure of GTK documentation is very readable and provides information about the widget hierarchy, available properties, signals and functions in a [single page](http://www.gtk.org/api/2.6/gtk/GtkComboBox.html) compared to the many different pages which the Motif combo box documentation is spread out over.

This makes me wonder how much naming conventions influence the development process and whether or not there is a correlation between good naming and good code or visa versa.


## API Template

The amount of extra fluff that goes into header files can be significant if you need to ensure compatibility between a wide range of compilers or platforms and to account for library versioning, but it's all necessary and part of good practice.

Whether or not to include documentation is up to the library author, the documentation can add a large number of extra lines, but the combination of a single file for the library containing everything the programmer needs to use it in one easy to find place can be invaluable.

What does this template account for?

 * Include guards
 * Version macros for compile-time checks
 * C++ compatibility
 * Symbol visibility in major compilers
 * Opaque pointer definitions
 * Library functions

Which compilers and platforms you need to be compatible with fluctuates from project to project, generally speaking the header files should adhere to [ANSI C](http://en.wikipedia.org/wiki/ANSI_C) and must compile cleanly with all possible compiler warning flags enabled. The most used compilers and platforms at the moment are:

 * GCC 4.x+
 * Clang 2.x+
 * MSVC 2005+
 * lcc-win32
 * FreeBSD
 * Windows
 * Linux
 * OS X

However if you follow the guidelines correctly it's not hard to make the API header compile cleanly on OpenVMS/VAX, IBM's z/OS, certain embedded targets and even early DOS C and C++ compilers; whether or not the rest of the library will compile and work is [another question entirely](http://www.youtube.com/watch?v=-jvLY5pUwic).

```c
#pragma once
#ifndef __ABC_H_INCLUDED__
#define __ABC_H_INCLUDED__

/*  Version macros for compile-time API version detection */
#define ABC_VERSION_MAJOR 1
#define ABC_VERSION_MINOR 2
#define ABC_VERSION_PATCH 3
#define ABC_MAKE_VERSION(major, minor, patch) \
    ((major) * 10000 + (minor) * 100 + (patch))
#define ABC_VERSION \
    ABC_MAKE_VERSION(ABC_VERSION_MAJOR, ABC_VERSION_MINOR, ABC_VERSION_PATCH)

#ifdef __cplusplus
extern "C" {
#endif

/* Handle DSO symbol visibility */
#if defined _WIN32
#   if defined ABC_STATIC
#       define ABC_EXPORT
#   elif defined DLL_EXPORT
#       define ABC_EXPORT __declspec(dllexport)
#   else
#       define ABC_EXPORT __declspec(dllimport)
#   endif
#else
#   if defined __SUNPRO_C  || defined __SUNPRO_CC
#       define ABC_EXPORT __global
#   elif (defined __GNUC__ && __GNUC__ >= 4) || defined __INTEL_COMPILER
#       define ABC_EXPORT __attribute__ ((visibility("default")))
#   else
#       define ABC_EXPORT
#   endif
#endif

/* APIs Opaque Types */
typedef void* abc_widget_o;

/* Library functions */
ABC_EXPORT void abc_version (int *major, int *minor, int *patch);
ABC_EXPORT abc_widget_o *abc_widget_new ();
ABC_EXPORT void abc_widget_free(abc_widget_o **widget);
ABC_EXPORT const char* abc_widget_get_label(const abc_widget_o *widget);
ABC_EXPORT int abc_widget_set_label(abc_widget_o *widget, const char *label);
ABC_EXPORT int abc_widget_isvalid(const abc_widget_o *widget);

#undef ABC_EXPORT

#ifdef __cplusplus
}
#endif

#endif
```

It's simple when everything's programmed into muscle memory :)


## Summary and Direction

Meta analysis of API design, methods of clean abstraction and common programming practice should always be fruitful even as a personal learning exercise - the end result is perfection and isn't achievable :)

Reflection brings me to define some mental guidelines for API development in C:

 * Use `const` whenever non-scalar arguments aren't modified by the function
 * Use underscores to separate the hierarchy of abstractions
 * Choose different names depending on who owns the memory, `init` and `destroy` if caller allocates or `new` and `free` if the callee allocates.

As it seems like C will be here for another decade or four it would be nice to see it continue moving in a good direction:

 * A `const` modifier on a function-level like C++ (GCC has the 'pure' attribute)
 * `_o` suffix could be adopted for opaque `void*` types, much like `_t`
 * Emphasis on practical abstraction as part of comp.sci
 * Discussion on common patterns found in C APIs



## Further Reading

 * [Creating great API documentation, tools and techniques](http://stackoverflow.com/questions/2001899/creating-great-api-documentation-tools-and-techniques)
 * [How do you define a good or bad api?](http://stackoverflow.com/questions/469161/how-do-you-define-a-good-or-bad-api)
 * [Who should allocate?](http://stackoverflow.com/questions/3296302/c-api-design-who-should-allocate)
 * [pthreads as a case study of good API design](http://eli.thegreenplace.net/2010/04/05/pthreads-as-a-case-study-of-good-api-design/)
 * [Basic C API Design Question](http://discuss.fogcreek.com/joelonsoftware4/default.asp?cmd=show&ixPost=117274&ixReplies=22)
 * [Opaque data pointers](http://blog.aaronballman.com/2011/07/opaque-data-pointers/)
 * [Implementing Abstraction with C](http://www.bottomupcs.com/abstration.html)
 * [How to Design a Good
API and Why it Matters](http://lcsd05.cs.tamu.edu/slides/keynote.pdf)
 * [C++ and Beyond 2012: Herb Sutter - You don't know \[blank\] and \[blank\]](http://channel9.msdn.com/posts/C-and-Beyond-2012-Herb-Sutter-You-dont-know-blank-and-blank)

-------------------

[Header image](http://www.flickr.com/photos/dannynic/8314091000/) by [Danny Nicholson](http://www.flickr.com/photos/dannynic/)