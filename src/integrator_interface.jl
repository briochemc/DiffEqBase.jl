resize!(i::DEIntegrator) = error("This method has not been implemented for the integrator")
cache_iter(i::DEIntegrator) = error("This method has not been implemented for the integrator")
terminate!(i::DEIntegrator) = error("This method has not been implemented for the integrator")
get_du(i::DEIntegrator) = error("This method has not been implemented for the integrator")
get_dt(i::DEIntegrator) = error("This method has not been implemented for the integrator")
get_proposed_dt(i::DEIntegrator) = error("This method has not been implemented for the integrator")
modify_proposed_dt!(i::DEIntegrator) = error("This method has not been implemented for the integrator")
u_unmodified!(i::DEIntegrator,bool) = error("This method has not been implemented for the integrator")

@recipe function f(i::DEIntegrator)
  i.sol
end
