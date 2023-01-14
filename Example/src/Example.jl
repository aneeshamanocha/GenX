module Example

export func


@doc raw"""
    vre_stor_reserves!(EP::Model, inputs::Dict, setup::Dict)

This function activates either or both frequency regulation and operating reserve options for co-located 
    VRE-storage resources. Co-located VRE and storage resources ($y \in \mathcal{VS}$) have six pairs of 
    auxilary variables to reflect contributions to regulation and reserves when generating electricity from 
    solar PV or wind resources, DC charging and discharging from storage resources, and AC charging and 
    discharging from storage resources. The primary variables ($f_{y,z,t}$ & $r_{y,z,t}$) becomes equal to the sum
    of these auxilary variables as follows:
```math
\begin{aligned}
    &  f_{y,z,t} = f^{pv}_{y,z,t} + f^{wind}_{y,z,t} + f^{dc,dis}_{y,z,t} + f^{dc,cha}_{y,z,t} + f^{ac,dis}_{y,z,t} + f^{ac,cha}_{y,z,t} & \quad \forall y \in \mathcal{VS}, z \in \mathcal{Z}, t \in \mathcal{T}\\
    &  r_{y,z,t} = r^{pv}_{y,z,t} + r^{wind}_{y,z,t} + r^{dc,dis}_{y,z,t} + r^{dc,cha}_{y,z,t} + r^{ac,dis}_{y,z,t} + r^{ac,cha}_{y,z,t} & \quad \forall y \in \mathcal{VS}, z \in \mathcal{Z}, t \in \mathcal{T}\\
\end{aligned}
```

Furthermore, the frequency regulation and operating reserves require the maximum contribution from the entire resource
    to be a specified fraction of the installed grid connection capacity:
```math
\begin{aligned}
    f_{y,z,t} \leq \upsilon^{reg}_{y,z} \times \Delta^{total}_{y,z}
    \hspace{4 cm}  \forall y \in \mathcal{VS}, z \in \mathcal{Z}, t \in \mathcal{T} \\
    r_{y,z,t} \leq \upsilon^{rsv}_{y,z}\times \Delta^{total}_{y,z}
    \hspace{4 cm}  \forall y \in \mathcal{VS}, z \in \mathcal{Z}, t \in \mathcal{T}
    \end{aligned}
```

The following constraints follow if the configurable co-located resource has any type of storage component. 
    When charging, reducing the DC and AC charge rate is contributing to upwards reserve and frequency regulation as 
    it drops net demand. As such, the sum of the DC and AC charge rate plus contribution to regulation and reserves 
    up must be greater than zero. Additionally, the DC and AC discharge rate plus the contribution to regulation must 
    be greater than zero:
```math
\begin{aligned}
    &  \Pi^{dc}_{y,z,t} - f^{dc,cha}_{y,z,t} - r^{dc,cha}_{y,z,t} \geq 0 & \quad \forall y \in \mathcal{VS}^{sym,dc} \cup \mathcal{VS}^{asym,dc,cha}, z \in \mathcal{Z}, t \in \mathcal{T}\\
    &  \Pi^{ac}_{y,z,t} - f^{ac,cha}_{y,z,t} - r^{ac,cha}_{y,z,t} \geq 0 & \quad \forall y \in \mathcal{VS}^{sym,ac} \cup \mathcal{VS}^{asym,ac,cha}, z \in \mathcal{Z}, t \in \mathcal{T}\\
    &  \Theta^{dc}_{y,z,t} - f^{dc,dis}_{y,z,t} \geq 0 & \quad \forall y \in \mathcal{VS}^{sym,dc} \cup \mathcal{VS}^{asym,dc,dis}, z \in \mathcal{Z}, t \in \mathcal{T} \\
    &  \Theta^{ac}_{y,z,t} - f^{ac,dis}_{y,z,t} \geq 0 & \quad \forall y \in \mathcal{VS}^{sym,ac} \cup \mathcal{VS}^{asym,ac,dis}, z \in \mathcal{Z}, t \in \mathcal{T}
\end{aligned}
```

Additionally, when reserves are modeled, the maximum DC and AC charge rate and contribution to regulation while charging can be 
    no greater than the available energy storage capacity, or the difference between the total energy storage capacity, 
    $\Delta^{total, energy}_{y,z}$, and the state of charge at the end of the previous time period, $\Gamma_{y,z,t-1}$, 
    while accounting for charging losses $\eta_{y,z}^{charge,dc}, \eta_{y,z}^{charge,ac}$. Note that for storage to contribute 
    to reserves down while charging, the storage device must be capable of increasing the charge rate (which increases net load):
```math
\begin{aligned}
    &  \eta_{y,z}^{charge,dc} \times (\Pi^{dc}_{y,z,t} + f^{dc,cha}_{o,z,t}) + \eta_{y,z}^{charge,ac} \times (\Pi^{ac}_{y,z,t} + f^{ac,cha}_{o,z,t}) \\
    & \leq \Delta^{energy, total}_{y,z} - \Gamma_{y,z,t-1} \quad \forall y \in \mathcal{VS}^{stor}, z \in \mathcal{Z}, t \in \mathcal{T}
\end{aligned}
```

Finally, the maximum DC and AC discharge rate and contributions to the frequency regulation and operating reserves must be 
    less than the state of charge in the previous time period, $\Gamma_{y,z,t-1}$. Without any capacity reserve margin policies activated, 
    the constraint is as follows:
```math
\begin{aligned}
    &  \frac{\Theta^{dc}_{y,z,t}+f^{dc,dis}_{y,z,t}+r^{dc,dis}_{y,z,t}}{\eta_{y,z}^{discharge,dc}} + \frac{\Theta^{ac}_{y,z,t}+f^{ac,dis}_{y,z,t}+r^{ac,dis}_{y,z,t}}{\eta_{y,z}^{discharge,ac}} \\
    & \leq \Gamma_{y,z,t-1} \quad \forall y \in \mathcal{VS}^{stor}, z \in \mathcal{Z}, t \in \mathcal{T}
\end{aligned}
```

With the capacity reserve margin policies, the maximum DC and AC discharge rate accounts for both contributions to the capacity reserve 
    margin and operating reserves as follows:
```math
\begin{aligned}
    &  \frac{\Theta^{dc}_{y,z,t}+\Theta^{CRM,dc}_{y,z,t}+f^{dc,dis}_{y,z,t}+r^{dc,dis}_{y,z,t}}{\eta_{y,z}^{discharge,dc}} + \frac{\Theta^{ac}_{y,z,t}+\Theta^{CRM,ac}_{y,z,t}+f^{ac,dis}_{y,z,t}+r^{ac,dis}_{y,z,t}}{\eta_{y,z}^{discharge,ac}} \\
    & \leq \Gamma_{y,z,t-1} \quad \forall y \in \mathcal{VS}^{stor}, z \in \mathcal{Z}, t \in \mathcal{T}
\end{aligned}
```

Lastly, if the co-located resource has a variable renewable energy component, the solar PV and wind resource can also contribute to frequency regulation reserves  
    and must be greater than zero:
```math
\begin{aligned}
    &  \Theta^{pv}_{y,z,t} - f^{pv}_{y,z,t} \geq 0 & \quad \forall y \in \mathcal{VS}^{pv}, z \in \mathcal{Z}, t \in \mathcal{T} \\
    &  \Theta^{wind}_{y,z,t} - f^{wind}_{y,z,t} \geq 0 & \quad \forall y \in \mathcal{VS}^{wind}, z \in \mathcal{Z}, t \in \mathcal{T}
\end{aligned}
```
"""
func(x) = 2x + 1

end