!=========================================================================
module m_hamiltonian_sca


contains


!=========================================================================
subroutine matrix_cart_to_local(ibf,jbf,li,lj,ni_cart,nj_cart,matrix_cart,ni,nj,m_ham,n_ham,matrix_local)
 use m_definitions
 use m_mpi
 use m_basis_set
 implicit none

 integer,intent(in)     :: ibf,jbf
 integer,intent(in)     :: li,lj
 integer,intent(in)     :: ni_cart,nj_cart,ni,nj
 integer,intent(in)     :: m_ham,n_ham
 real(dp),intent(in)    :: matrix_cart(ni_cart,nj_cart)
 real(dp),intent(inout) :: matrix_local(m_ham,n_ham)
!=====
 integer  :: iglobal,jglobal
 integer  :: ilocal,jlocal
 real(dp) :: matrix_final(ibf:ibf+ni-1,jbf:jbf+nj-1)
!=====

 matrix_final(:,:) = MATMUL( TRANSPOSE(cart_to_pure(li)%matrix(:,:)) , &
                             MATMUL( matrix_cart(:,:) , cart_to_pure(lj)%matrix(:,:) ) )

 do jglobal=jbf,jbf+nj-1
   jlocal = colindex_global_to_local('H',jglobal)
   if( jlocal == 0 ) cycle

   do iglobal=ibf,ibf+ni-1
     ilocal = rowindex_global_to_local('H',iglobal)
     if( ilocal == 0 ) cycle

     matrix_local(ilocal,jlocal) = matrix_final(iglobal,jglobal)

   enddo
 enddo


end subroutine matrix_cart_to_local


!=========================================================================
subroutine setup_overlap_sca(print_matrix_,basis,m_ham,n_ham,s_matrix)
 use m_definitions
 use m_timing
 use m_basis_set
 implicit none
 logical,intent(in)         :: print_matrix_
 type(basis_set),intent(in) :: basis
 integer,intent(in)         :: m_ham,n_ham
 real(dp),intent(out)       :: s_matrix(m_ham,n_ham)
!=====
 integer              :: ibf,jbf
 integer              :: ibf_cart,jbf_cart
 integer              :: i_cart,j_cart
 integer              :: ni,nj,ni_cart,nj_cart,li,lj
 character(len=100)   :: title
 real(dp),allocatable :: matrix_cart(:,:)
!=====

 call start_clock(timing_overlap)
 write(stdout,'(/,a)') ' Setup overlap matrix S: SCALAPACK'

 ibf_cart = 1
 jbf_cart = 1
 ibf      = 1
 jbf      = 1
 do while(ibf_cart<=basis%nbf_cart)
   li      = basis%bf(ibf_cart)%am
   ni_cart = number_basis_function_am('CART',li)
   ni      = number_basis_function_am(basis%gaussian_type,li)

   do while(jbf_cart<=basis%nbf_cart)
     lj      = basis%bf(jbf_cart)%am
     nj_cart = number_basis_function_am('CART',lj)
     nj      = number_basis_function_am(basis%gaussian_type,lj)

     allocate(matrix_cart(ni_cart,nj_cart))
     do i_cart=1,ni_cart
       do j_cart=1,nj_cart
         call overlap_basis_function(basis%bf(ibf_cart+i_cart-1),basis%bf(jbf_cart+j_cart-1),matrix_cart(i_cart,j_cart))
       enddo
     enddo

     call matrix_cart_to_local(ibf,jbf,li,lj,ni_cart,nj_cart,matrix_cart,ni,nj,m_ham,n_ham,s_matrix)


     deallocate(matrix_cart)
     jbf      = jbf      + nj
     jbf_cart = jbf_cart + nj_cart
   enddo
   jbf      = 1
   jbf_cart = 1

   ibf      = ibf      + ni
   ibf_cart = ibf_cart + ni_cart

 enddo

 title='=== Overlap matrix S ==='
 call dump_out_matrix(print_matrix_,title,basis%nbf,1,s_matrix)

 call stop_clock(timing_overlap)


end subroutine setup_overlap_sca


!=========================================================================
subroutine setup_kinetic_sca(print_matrix_,basis,m_ham,n_ham,hamiltonian_kinetic)
 use m_definitions
 use m_timing
 use m_basis_set
 implicit none
 logical,intent(in)         :: print_matrix_
 type(basis_set),intent(in) :: basis
 integer,intent(in)         :: m_ham,n_ham
 real(dp),intent(out)       :: hamiltonian_kinetic(m_ham,n_ham)
!=====
 integer              :: ibf,jbf
 integer              :: ibf_cart,jbf_cart
 integer              :: i_cart,j_cart,iglobal,jglobal,ilocal,jlocal
 integer              :: ni,nj,ni_cart,nj_cart,li,lj
 character(len=100)   :: title
 real(dp),allocatable :: matrix_cart(:,:)
 real(dp),allocatable :: matrix_final(:,:)
!=====

 call start_clock(timing_hamiltonian_kin)
 write(stdout,'(/,a)') ' Setup kinetic part of the Hamiltonian: SCALAPACK'

 ibf_cart = 1
 jbf_cart = 1
 ibf      = 1
 jbf      = 1
 do while(ibf_cart<=basis%nbf_cart)
   li      = basis%bf(ibf_cart)%am
   ni_cart = number_basis_function_am('CART',li)
   ni      = number_basis_function_am(basis%gaussian_type,li)

   do while(jbf_cart<=basis%nbf_cart)
     lj      = basis%bf(jbf_cart)%am
     nj_cart = number_basis_function_am('CART',lj)
     nj      = number_basis_function_am(basis%gaussian_type,lj)

     allocate(matrix_cart(ni_cart,nj_cart))
     allocate(matrix_final(ni,nj))
     do i_cart=1,ni_cart
       do j_cart=1,nj_cart
         call kinetic_basis_function(basis%bf(ibf_cart+i_cart-1),basis%bf(jbf_cart+j_cart-1),matrix_cart(i_cart,j_cart))
       enddo
     enddo

     call matrix_cart_to_local(ibf,jbf,li,lj,ni_cart,nj_cart,matrix_cart,ni,nj,m_ham,n_ham,hamiltonian_kinetic)

     deallocate(matrix_cart,matrix_final)
     jbf      = jbf      + nj
     jbf_cart = jbf_cart + nj_cart
   enddo
   jbf      = 1
   jbf_cart = 1

   ibf      = ibf      + ni
   ibf_cart = ibf_cart + ni_cart

 enddo

 title='===  Kinetic energy contribution ==='
 call dump_out_matrix(print_matrix_,title,basis%nbf,1,hamiltonian_kinetic)

 call stop_clock(timing_hamiltonian_kin)

end subroutine setup_kinetic_sca


!=========================================================================
subroutine setup_nucleus_sca(print_matrix_,basis,m_ham,n_ham,hamiltonian_nucleus)
 use m_definitions
 use m_timing
 use m_basis_set
 use m_atoms
 implicit none
 logical,intent(in)         :: print_matrix_
 type(basis_set),intent(in) :: basis
 integer,intent(in)         :: m_ham,n_ham
 real(dp),intent(out)       :: hamiltonian_nucleus(m_ham,n_ham)
!=====
 integer              :: natom_local
 integer              :: ibf,jbf
 integer              :: ibf_cart,jbf_cart
 integer              :: i_cart,j_cart
 integer              :: ni,nj,ni_cart,nj_cart,li,lj
 integer              :: iatom
 character(len=100)   :: title
 real(dp),allocatable :: matrix_cart(:,:)
 real(dp)             :: vnucleus_ij
!=====

 call start_clock(timing_hamiltonian_nuc)
 write(stdout,'(/,a)') ' Setup nucleus-electron part of the Hamiltonian: SCALAPACK'
! if( nproc > 1 ) then
!   natom_local=0
!   do iatom=1,natom
!     if( rank /= MODULO(iatom-1,nproc) ) cycle
!     natom_local = natom_local + 1
!   enddo
!   write(stdout,'(a)')         '   Parallelizing over atoms'
!   write(stdout,'(a,i5,a,i5)') '   this proc treats ',natom_local,' over ',natom
! endif

 ibf_cart = 1
 jbf_cart = 1
 ibf      = 1
 jbf      = 1
 do while(ibf_cart<=basis%nbf_cart)
   li      = basis%bf(ibf_cart)%am
   ni_cart = number_basis_function_am('CART',li)
   ni      = number_basis_function_am(basis%gaussian_type,li)

   do while(jbf_cart<=basis%nbf_cart)
     lj      = basis%bf(jbf_cart)%am
     nj_cart = number_basis_function_am('CART',lj)
     nj      = number_basis_function_am(basis%gaussian_type,lj)

     allocate(matrix_cart(ni_cart,nj_cart))
     matrix_cart(:,:) = 0.0_dp
     do iatom=1,natom
!FBFBSCA    if( rank /= MODULO(iatom-1,nproc) ) cycle
       do i_cart=1,ni_cart
         do j_cart=1,nj_cart
           call nucleus_basis_function(basis%bf(ibf_cart+i_cart-1),basis%bf(jbf_cart+j_cart-1),zatom(iatom),x(:,iatom),vnucleus_ij)
           matrix_cart(i_cart,j_cart) = matrix_cart(i_cart,j_cart) + vnucleus_ij
         enddo
       enddo
     enddo
!     hamiltonian_nucleus(ibf:ibf+ni-1,jbf:jbf+nj-1) = MATMUL( TRANSPOSE(cart_to_pure(li)%matrix(:,:)) , &
!                                                              MATMUL( matrix_cart(:,:) , cart_to_pure(lj)%matrix(:,:) ) ) 

     call matrix_cart_to_local(ibf,jbf,li,lj,ni_cart,nj_cart,matrix_cart,ni,nj,m_ham,n_ham,hamiltonian_nucleus)


     deallocate(matrix_cart)
     jbf      = jbf      + nj
     jbf_cart = jbf_cart + nj_cart
   enddo
   jbf      = 1
   jbf_cart = 1

   ibf      = ibf      + ni
   ibf_cart = ibf_cart + ni_cart

 enddo

!FBFBSCA !
!FBFBSCA ! Reduce operation
!FBFBSCA call xsum(hamiltonian_nucleus)

 title='===  Nucleus potential contribution ==='
 call dump_out_matrix(print_matrix_,title,basis%nbf,1,hamiltonian_nucleus)

 call stop_clock(timing_hamiltonian_nuc)

end subroutine setup_nucleus_sca


!=========================================================================
subroutine setup_hartree_ri_sca(print_matrix_,nbf,m_ham,n_ham,nspin,p_matrix,pot_hartree,ehartree)
 use m_definitions
 use m_mpi
 use m_timing
 use m_eri
 implicit none
 logical,intent(in)   :: print_matrix_
 integer,intent(in)   :: nbf,m_ham,n_ham,nspin
 real(dp),intent(in)  :: p_matrix(m_ham,n_ham,nspin)
 real(dp),intent(out) :: pot_hartree(m_ham,n_ham)
 real(dp),intent(out) :: ehartree
!=====
 integer              :: ilocal,jlocal
 integer              :: iglobal,jglobal
 integer              :: ibf,jbf,kbf,lbf,ispin
 integer              :: ibf_auxil,ipair
 integer              :: index_ij,index_kl
 real(dp),allocatable :: partial_sum(:)
 real(dp)             :: rtmp
 character(len=100)   :: title
!=====

 write(stdout,*) 'Calculate Hartree term with Resolution-of-Identity: SCALAPACK'
 call start_clock(timing_hartree)

 allocate(partial_sum(nauxil_3center))
 partial_sum(:) = 0.0_dp

 do jlocal=1,n_ham
   jglobal = colindex_local_to_global('H',jlocal)

   do ilocal=1,m_ham
     iglobal = rowindex_local_to_global('H',ilocal)
     if( negligible_basispair(iglobal,jglobal) ) cycle

!     write(stdout,'(a,5(x,i6))') 'FBFBSCA',ilocal,jlocal,iglobal,jglobal,index_pair(iglobal,jglobal)
     partial_sum(:) = partial_sum(:) + eri_3center(:,index_pair(iglobal,jglobal)) * SUM( p_matrix(ilocal,jlocal,:) )   !FBFBSCA distribute eri_3center

   enddo
 enddo

 call xtrans_sum(partial_sum)


! do ipair=1,npair
!   kbf = index_basis(1,ipair)
!   lbf = index_basis(2,ipair)
!   ! Factor 2 comes from the symmetry of p_matrix
!   partial_sum(:) = partial_sum(:) + eri_3center(:,ipair) * SUM( p_matrix(kbf,lbf,:) ) * 2.0_dp
!   ! Then diagonal terms have been counted twice and should be removed once.
!   if( kbf == lbf ) &
!     partial_sum(:) = partial_sum(:) - eri_3center(:,ipair) * SUM( p_matrix(kbf,kbf,:) )
! enddo

 ! Hartree potential is not sensitive to spin
 pot_hartree(:,:) = 0.0_dp
 do jlocal=1,n_ham
   jglobal = colindex_local_to_global('H',jlocal)

   do ilocal=1,m_ham
     iglobal = rowindex_local_to_global('H',ilocal)
     if( negligible_basispair(iglobal,jglobal) ) cycle

     pot_hartree(ilocal,jlocal) = SUM( partial_sum(:) * eri_3center(:,index_pair(iglobal,jglobal)) )

   enddo
 enddo

 

! ! Hartree potential is not sensitive to spin
! pot_hartree(:,:) = 0.0_dp
! do ipair=1,npair
!   ibf = index_basis(1,ipair)
!   jbf = index_basis(2,ipair)
!   rtmp = DOT_PRODUCT( eri_3center(:,ipair) , partial_sum(:) )
!   pot_hartree(ibf,jbf) = rtmp
!   pot_hartree(jbf,ibf) = rtmp
! enddo

 deallocate(partial_sum)

 !
 ! Sum up the different contribution from different procs only if needed
 call xlocal_sum(pot_hartree)
! call xsum(pot_hartree)


 title='=== Hartree contribution ==='
 call dump_out_matrix(print_matrix_,title,nbf,1,pot_hartree)

 !
 ! Calculate the Hartree energy
 if( cntxt_ham > 0 ) then
   ehartree = 0.5_dp*SUM(pot_hartree(:,:) * SUM(p_matrix(:,:,:),DIM=3) )
 else
   ehartree = 0.0_dp
 endif
 call xsum(ehartree)


 call stop_clock(timing_hartree)


end subroutine setup_hartree_ri_sca


!=========================================================================
subroutine setup_exchange_ri_sca(print_matrix_,nbf,m_ham,n_ham,occupation,c_matrix,p_matrix,pot_exchange,eexchange)
 use m_definitions
 use m_mpi
 use m_timing
 use m_eri
 use m_inputparam,only: nspin,spin_fact
 implicit none
 logical,intent(in)   :: print_matrix_
 integer,intent(in)   :: nbf,m_ham,n_ham
 real(dp),intent(in)  :: occupation(nbf,nspin)
 real(dp),intent(in)  :: c_matrix(m_ham,n_ham,nspin)
 real(dp),intent(in)  :: p_matrix(m_ham,n_ham,nspin)
 real(dp),intent(out) :: pot_exchange(m_ham,n_ham,nspin)
 real(dp),intent(out) :: eexchange
!=====
 integer              :: ibf,jbf,kbf,lbf,ispin,istate,ibf_auxil
 integer              :: index_ij
 integer              :: nocc
 real(dp),allocatable :: tmpa(:,:)
 real(dp),allocatable :: tmpb(:,:)
 real(dp)             :: eigval(nbf)
 integer              :: ipair
 real(dp)             :: c_matrix_i(nbf)
 integer              :: iglobal,jglobal,ilocal,jlocal
 integer              :: ii
!=====

 write(stdout,*) 'Calculate Exchange term with Resolution-of-Identity: SCALAPACK'
 call start_clock(timing_exchange)


 pot_exchange(:,:,:) = 0.0_dp

 allocate(tmpa(nauxil_3center,m_ham))
 allocate(tmpb(nauxil_3center,n_ham))


 do ispin=1,nspin
   do istate=1,nbf

     if( occupation(istate,ispin) < completely_empty ) cycle

     !
     ! First all processors must have the c_matrix for (istate, ispin)
     c_matrix_i(:) = 0.0_dp
     if( cntxt_ham > 0 ) then
       jlocal = colindex_global_to_local('H',istate)
       if( jlocal /= 0 ) then
         do ilocal=1,m_ham
           iglobal = rowindex_local_to_global('H',ilocal)
           c_matrix_i(iglobal) = c_matrix(ilocal,jlocal,ispin) * SQRT( occupation(istate,ispin) )
         enddo
       endif
     endif
     call xsum(c_matrix_i)

     tmpa(:,:) = 0.0_dp
     do ilocal=1,m_ham
       iglobal = rowindex_local_to_global('H',ilocal)

       do ii=1,nbf
         if( negligible_basispair(ii,iglobal) ) cycle
         tmpa(:,ilocal) = tmpa(:,ilocal) + eri_3center(:,index_pair(ii,iglobal)) * c_matrix_i(ii) 
       enddo
     enddo

     tmpb(:,:) = 0.0_dp

     do jlocal=1,n_ham
       jglobal = colindex_local_to_global('H',jlocal)

       do ii=1,nbf
         if( negligible_basispair(ii,jglobal) ) cycle
         tmpb(:,jlocal) = tmpb(:,jlocal) + eri_3center(:,index_pair(ii,jglobal)) * c_matrix_i(ii)
       enddo
     enddo

     pot_exchange(:,:,ispin) = pot_exchange(:,:,ispin)  &
                        - MATMUL( TRANSPOSE(tmpa(:,:)) , tmpb(:,:) ) / spin_fact


   enddo
 enddo

 call xlocal_sum(pot_exchange)

 !
 ! Calculate the Hartree energy
 if( cntxt_ham > 0 ) then
   eexchange = 0.5_dp * SUM( pot_exchange(:,:,:) * p_matrix(:,:,:) )
 else
   eexchange = 0.0_dp
 endif
 call xsum(eexchange)



! do ispin=1,nspin
!
!   ! Denombrate the strictly positive eigenvalues
!   nocc = COUNT( occupation(:,ispin) > completely_empty )
!
!   do istate=1,nocc
!     tmp(:,:) = 0.0_dp
!     do ipair=1,npair
!       ibf=index_basis(1,ipair)
!       jbf=index_basis(2,ipair)
!       tmp(:,ibf) = tmp(:,ibf) + c_matrix(jbf,istate,ispin) * eri_3center(:,ipair) * SQRT( occupation(istate,ispin) )
!       if( ibf /= jbf ) &
!            tmp(:,jbf) = tmp(:,jbf) + c_matrix(ibf,istate,ispin) * eri_3center(:,ipair) * SQRT( occupation(istate,ispin) )
!     enddo
!
!     pot_exchange(:,:,ispin) = pot_exchange(:,:,ispin) &
!                        - MATMUL( TRANSPOSE(tmp(:,:)) , tmp(:,:) ) / spin_fact
!   enddo
!
! enddo
! deallocate(tmpa,tmpb)
!
! call xsum(pot_exchange)
!
! call dump_out_matrix(print_matrix_,'=== Exchange contribution ===',nbf,nspin,pot_exchange)
!
! eexchange = 0.5_dp*SUM(pot_exchange(:,:,:)*p_matrix(:,:,:))

 call stop_clock(timing_exchange)

end subroutine setup_exchange_ri_sca


!=========================================================================
subroutine setup_exchange_longrange_ri_sca(print_matrix_,nbf,occupation,c_matrix,p_matrix,pot_exchange,eexchange)
 use m_definitions
 use m_mpi
 use m_timing
 use m_eri
 use m_inputparam,only: nspin,spin_fact
 implicit none
 logical,intent(in)   :: print_matrix_
 integer,intent(in)   :: nbf
 real(dp),intent(in)  :: occupation(nbf,nspin)
 real(dp),intent(in)  :: c_matrix(nbf,nbf,nspin)
 real(dp),intent(in)  :: p_matrix(nbf,nbf,nspin)
 real(dp),intent(out) :: pot_exchange(nbf,nbf,nspin)
 real(dp),intent(out) :: eexchange
!=====
 integer              :: ibf,jbf,kbf,lbf,ispin,istate,ibf_auxil
 integer              :: index_ij
 integer              :: nocc
 real(dp),allocatable :: tmp(:,:)
 real(dp)             :: eigval(nbf)
 integer              :: ipair
!=====

 write(stdout,*) 'Calculate LR Exchange term with Resolution-of-Identity: SCALAPACK'
 call start_clock(timing_exchange)


 pot_exchange(:,:,:)=0.0_dp

 allocate(tmp(nauxil_3center_lr,nbf))

 do ispin=1,nspin

   ! Denombrate the strictly positive eigenvalues
   nocc = COUNT( occupation(:,ispin) > completely_empty )

   do istate=1,nocc
     tmp(:,:) = 0.0_dp
     do ipair=1,npair
       ibf=index_basis(1,ipair)
       jbf=index_basis(2,ipair)
       tmp(:,ibf) = tmp(:,ibf) + c_matrix(jbf,istate,ispin) * eri_3center_lr(:,ipair) * SQRT( occupation(istate,ispin) )
       if( ibf /= jbf ) &
            tmp(:,jbf) = tmp(:,jbf) + c_matrix(ibf,istate,ispin) * eri_3center_lr(:,ipair) * SQRT( occupation(istate,ispin) )
     enddo

     pot_exchange(:,:,ispin) = pot_exchange(:,:,ispin) &
                        - MATMUL( TRANSPOSE(tmp(:,:)) , tmp(:,:) ) / spin_fact
   enddo

 enddo
 deallocate(tmp)

 call xsum(pot_exchange)

 call dump_out_matrix(print_matrix_,'=== LR Exchange contribution ===',nbf,nspin,pot_exchange)

 eexchange = 0.5_dp*SUM(pot_exchange(:,:,:)*p_matrix(:,:,:))

 call stop_clock(timing_exchange)

end subroutine setup_exchange_longrange_ri_sca


!=========================================================================
subroutine setup_density_matrix_sca(nbf,m_ham,n_ham,c_matrix,occupation,p_matrix)
 use m_definitions
 use m_mpi
 use m_inputparam,only: nspin
 implicit none
 integer,intent(in)   :: nbf,m_ham,n_ham
 real(dp),intent(in)  :: c_matrix(m_ham,n_ham,nspin)
 real(dp),intent(in)  :: occupation(nbf,nspin)
 real(dp),intent(out) :: p_matrix(m_ham,n_ham,nspin)
!=====
 integer  :: ispin,jlocal,jglobal
 real(dp) :: matrix_tmp(m_ham,n_ham)
!=====

 if( cntxt_ham > 0 ) then
   do ispin=1,nspin
     do jlocal=1,n_ham
       jglobal = colindex_local_to_global('H',jlocal)
       matrix_tmp(:,jlocal) = c_matrix(:,jlocal,ispin) * SQRT( occupation(jglobal,ispin) )
     enddo

     call PDGEMM('N','T',nbf,nbf,nbf,1.0_dp,matrix_tmp,1,1,desc_ham,           &
                  matrix_tmp,1,1,desc_ham,0.0_dp,                              &
                  p_matrix,1,1,desc_ham)


   enddo
 else
   p_matrix(:,:,:) = 0.0_dp
 endif

 ! Poor man distribution
 call xlocal_sum(p_matrix)


end subroutine setup_density_matrix_sca


!=========================================================================
subroutine diagonalize_hamiltonian_sca(nspin_local,nbf,m_ham,n_ham,nstate,hamiltonian,s_matrix_sqrt_inv,energy,c_matrix)
 use m_definitions
 use m_timing
 use m_mpi
 implicit none

 integer,intent(in)   :: nspin_local,nbf,nstate,m_ham,n_ham
 real(dp),intent(in)  :: hamiltonian(m_ham,n_ham,nspin_local)
 real(dp),intent(in)  :: s_matrix_sqrt_inv(m_ham,n_ham)
 real(dp),intent(out) :: c_matrix(m_ham,n_ham,nspin_local)
 real(dp),intent(out) :: energy(nbf,nspin_local)
!=====
 integer  :: ispin,ibf,jbf,istate
 real(dp) :: h_small(m_ham,n_ham) !(nstate,nstate)
 real(dp) :: matrix_tmp(m_ham,n_ham)
 integer  :: ilocal,jlocal
!=====

 energy(:,:) = 1.0e+10_dp
 c_matrix(:,:,:) = 0.0_dp
! do ibf=1,nbf
!   c_matrix(ibf,ibf,:) = 1.0_dp
! enddo

 ilocal = rowindex_global_to_local('H',101)
 jlocal = colindex_global_to_local('H',101)


 if(cntxt_ham > 0 ) then
   do ispin=1,nspin_local
     write(stdout,'(a,i3)') ' Diagonalization for spin: ',ispin
     call start_clock(timing_diago_hamiltonian)

!     h_small(:,:) = MATMUL( TRANSPOSE(s_matrix_sqrt_inv(:,:)) , &
!                              MATMUL( hamiltonian(:,:,ispin) , s_matrix_sqrt_inv(:,:) ) )

     !
     ! H = ^tS^{-1/2} H S^{-1/2}
     call PDGEMM('N','N',nbf,nbf,nbf,1.0_dp,hamiltonian(:,:,ispin),1,1,desc_ham,      &
                  s_matrix_sqrt_inv,1,1,desc_ham,0.0_dp,                              &
                  matrix_tmp,1,1,desc_ham)

     call PDGEMM('T','N',nbf,nbf,nbf,1.0_dp,s_matrix_sqrt_inv,1,1,desc_ham,           &
                  matrix_tmp,1,1,desc_ham,0.0_dp,                              &
                  h_small,1,1,desc_ham)



     call diagonalize_sca(desc_ham,nbf,m_ham,n_ham,h_small,energy(:,ispin))


!     c_matrix(:,1:nstate,ispin) = MATMUL( s_matrix_sqrt_inv(:,:) , h_small(:,:) )

     !
     ! C = S^{-1/2} C 
     call PDGEMM('N','N',nbf,nbf,nbf,1.0_dp,s_matrix_sqrt_inv,1,1,desc_ham,      &
                  h_small,1,1,desc_ham,0.0_dp,                              &
                  c_matrix(:,:,ispin),1,1,desc_ham)



     call stop_clock(timing_diago_hamiltonian)
   enddo

 else
   energy(:,:) = 0.0_dp
   c_matrix(:,:,:) = 0.0_dp
 endif

 ! Poor man distribution
 call xlocal_sum(energy)
 call xlocal_sum(c_matrix)



end subroutine diagonalize_hamiltonian_sca


!=========================================================================
subroutine setup_sqrt_overlap_sca(TOL_OVERLAP,nbf,m_ham,n_ham,s_matrix,nstate,s_matrix_sqrt_inv)
 use m_definitions
 use m_timing
 use m_warning
 use m_tools
 use m_mpi
 implicit none

 real(dp),intent(in)                :: TOL_OVERLAP
 integer,intent(in)                 :: nbf,m_ham,n_ham
 real(dp),intent(in)                :: s_matrix(m_ham,n_ham)
 integer,intent(out)                :: nstate
 real(dp),allocatable,intent(inout) :: s_matrix_sqrt_inv(:,:)
!=====
 real(dp) :: TOL_OVERLAP_FAKE=-1.0_dp
 real(dp) :: matrix_tmp(m_ham,n_ham)
 integer  :: ibf,jbf,jlocal,jglobal
 integer  :: ilocal
 real(dp) :: s_eigval(nbf)
 integer  :: desc1(ndel),desc2(ndel)
!=====

 call issue_warning('NO FILTERING IMPLEMENTED SO FAR: TOL_OVERLAP_FAKE TO BE REMOVED')

 if( cntxt_ham > 0 ) then
   matrix_tmp(:,:) = s_matrix(:,:)
   call diagonalize_sca(desc_ham,nbf,m_ham,n_ham,matrix_tmp,s_eigval)
   nstate = COUNT( s_eigval(:) > TOL_OVERLAP_FAKE )
 else
   nstate = 0
 endif

 ! Propagate nstate
 call xlocal_max(nstate)
 allocate(s_matrix_sqrt_inv(m_ham,n_ham)) ! FBFBSCA  deal with nstate /= nbf

 write(stdout,'(/,a)')       ' Filtering basis functions that induce overcompleteness'
 write(stdout,'(a,es9.2)')   '   Lowest S eigenvalue is           ',MINVAL( s_eigval(:) )
 write(stdout,'(a,es9.2)')   '   Tolerance on overlap eigenvalues ',TOL_OVERLAP_FAKE
 write(stdout,'(a,i5,a,i5)') '   Retaining ',nstate,' among ',nbf

 if( cntxt_ham > 0 ) then

!   ibf=0
!   do jbf=1,nbf
!     jlocal = colindex_global_to_local('H',jbf)
!     if( jlocal == 0 ) cycle
!     
!     if( s_eigval(jbf) > TOL_OVERLAP_FAKE ) then
!!FBFBSCA    ibf = ibf + 1
!       ibf = jlocal
!       s_matrix_sqrt_inv(:,ibf) = matrix_tmp(:,jlocal) / SQRT( s_eigval(jbf) )
!     endif
!   enddo

  do jlocal=1,n_ham
    jglobal = colindex_local_to_global('H',jlocal)
    s_matrix_sqrt_inv(:,jlocal) = matrix_tmp(:,jlocal) / SQRT( s_eigval(jglobal) )
  enddo

!!TEST FBFBSCA
!     call PDGEMM('N','T',nbf,nbf,nbf,1.0_dp,s_matrix_sqrt_inv,1,1,desc_ham,      &
!                  s_matrix_sqrt_inv,1,1,desc_ham,0.0_dp,                         &
!                  matrix_tmp,1,1,desc_ham)
!   

 endif


end subroutine setup_sqrt_overlap_sca


!=========================================================================
end module m_hamiltonian_sca
!=========================================================================