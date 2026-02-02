(lang dune 3.21)

(using rocq 0.11)

(using menhir 3.0)

(using directory-targets 0.1)

(name compcert)

(generate_opam_files)

(package
 (name compcert)
 (synopsis "Full Compcert Compiler"))

(package
 (name MenhirLib)
 (synopsis "Menhir Components"))

(package
 (name Flocq)
 (synopsis "Flocq Components"))

(package
 (name documentation)
 (allow_empty)
 (synopsis "Documentation for compcert")
 (depends compcert MenhirLib Flocq rocq-core rocq-stdlib))
