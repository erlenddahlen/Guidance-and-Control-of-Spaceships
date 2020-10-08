T1 = T2 = 20;
T6 = 10; 
k = 0.1; 
Cr = 0;
epsilon = 0.001; 

MA = [Xu_dot Yu_dot 0 
      Xv_dot Yv_dot 0
      0 Nv Nr_dot];

%Diagonal linear damping matrix D (Example 6.3)
Xu = -(m-MA(1,1))/T1;
Yv = -(m-MA(2,2))/T2;
Nr = -(Iz-MA(3,3))/T6;

D = [ Xu 0 0 
      0 Yv Yr
      0 Nv Nr];

% Nonlinear surge damping 


Cd = Hoerner(B,T); % Beam B and length T

% Strip theory: cross−flow drag integrals
dx = L/10; % 10 strips
for xL = -L/2:dx:L/2
Ucf = abs(v_r + xL * r) * (v_r + xL * r);
Yh = Yh - 0.5 * rho * T * Cd_2D * Ucf * dx; % sway force
Nh = Nh - 0.5 * rho * T * Cd_2D * xL * Ucf * dx; % yaw moment
end
