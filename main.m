% Project in TTK4190 Guidance and Control of Vehicles 
%
% Author:           My name
% Study program:    My study program

clear;
clc;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% USER INPUTS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
h  = 0.1;    % sampling time [s]
Ns = 10000;  % no. of samples

psi_ref = 10 * pi/180;  % desired yaw angle (rad)
U_d = 7;                % desired cruise speed (m/s)
               
% ship parameters 
m = 17.0677e6;          % mass (kg)
Iz = 2.1732e10;         % yaw moment of inertia about CO (kg m^3)
xg = -3.7;              % CG x-ccordinate (m)
L = 161;                % length (m)
B = 21.8;               % beam (m)
T = 8.9;                % draft (m)
KT = 0.7;               % propeller coefficient (-)
Dia = 3.3;              % propeller diameter (m)
rho = 1025;             % density of water (kg/m^3)
visc = 1e-6;            % kinematic viscousity at 20 degrees (m/s^2)
eps = 0.001;            % a small number added to ensure that the denominator of Cf is well defined at u=0
k = 0.1;                % form factor giving a viscous correction
t_thr = 0.05;           % thrust deduction number
d = m/T;
Im = 100000; 
Tm = 10; 
Km = 0.6; 


% rudder limitations
delta_max  = 40 * pi/180;        % max rudder angle      (rad)
Ddelta_max = 5  * pi/180;        % max rudder derivative (rad/s)

% added mass matrix about CO
Xudot = -8.9830e5;
Yvdot = -5.1996e6;
Yrdot =  9.3677e5;
Nvdot =  Yrdot;
Nrdot = -2.4283e10;
MA = -[ Xudot 0    0 
        0 Yvdot Yrdot
        0 Nvdot Nrdot ];

% rigid-body mass matrix
MRB = [ m 0    0 
        0 m    m*xg
        0 m*xg Iz ];
    
Minv = inv(MRB + MA); % Added mass is included to give the total inertia

% ocean current in NED
Vc = 1;                             % current speed (m/s)
betaVc = deg2rad(45);               % current direction (rad)

% wind expressed in NED
Vw = 10;                   % wind speed (m/s)
betaVw = deg2rad(135);     % wind direction (rad)
rho_a = 1.247;             % air density at 10 deg celsius
cy = 0.95;                 % wind coefficient in sway
cn = 0.15;                 % wind coefficient in yaw
A_Lw = 10 * L;             % projected lateral area
pa = 1.247;
A_Fw = 10*B;

% linear damping matrix (only valid for zero speed)
T1 = 20; T2 = 20; T6 = 10;

Xu = -(m - Xudot) / T1;
Yv = -(m - Yvdot) / T2;
Nr = -(Iz - Nrdot)/ T6;
D = diag([-Xu -Yv -Nr]);         % zero speed linear damping

% rudder coefficients (Section 9.5)
b = 2;
AR = 8;
CB = 0.8;

lambda = b^2 / AR;
tR = 0.45 - 0.28*CB;
CN = 6.13*lambda / (lambda + 2.25);
aH = 0.75;
xH = -0.4 * L;
xR = -0.5 * L;

X_delta2 = 0.5 * (1 - tR) * rho * AR * CN;
Y_delta = 0.25 * (1 + aH) * rho * AR * CN; 
N_delta = 0.25 * (xR + aH*xH) * rho * AR * CN;   

% input matrix
Bu = @(u_r,delta) [ (1-t_thr)  -u_r^2 * X_delta2 * delta
                        0      -u_r^2 * Y_delta
                        0      -u_r^2 * N_delta            ];
                    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                    
% Heading Controller
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% rudder control law
wb = 0.06;
zeta = 1;
wn = 1 / sqrt( 1 - 2*zeta^2 + sqrt( 4*zeta^4 - 4*zeta^2 + 2) ) * wb;
wref = 0.03;

% PID controller 
T = 168.9;
K = 0.00749;
m_control = T/K;
d_control = 1/K;

Kp = m_control*wn^2; 
Kd = 2*zeta*wn*m_control-d_control;
Ki = wn*Kp/10;

Ad = [0 1 0;
    0 0 1;      
    -wref^3  -3*wref^2  -3*wref ];   
Bd = [0 0 wref^3]'; 

e_psi = 0;
e_psi_integral = 0;
e_psi_diff = 0;
e_psi_prev = 0;

% linearized sway-yaw model (see (7.15)-(7.19) in Fossen (2021)) used
% for controller design. The code below should be modified.
N_lin = [];
b_lin = [-2*U_d*Y_delta -2*U_d*N_delta]';

% initial states
eta = [0 0 0]'; % NED x,y,yaw , position 
nu  = [0.1 0 0]'; %surge-sway-yaw, velocities
delta = 0;
n = 0;
xd = [0;0;0];


  
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Part 3 Speed control 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Ja = 0; 
PD = 1.5; 
AEAO = 0.65; 
z = 4; % Number of propellers
[KT,KQ] = wageningen(Ja,PD,AEAO,z);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Part 4
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
WP = load('WP.mat');
WP = WP.WP; 
R = 20*L; 
counter = 2;
x1 = 0;
y1 = 0;
x2 = WP(1, counter);
y2 = WP(2, counter);
K_p = 400; 

psi_ref = LOS(eta(1),eta(2),x1,y1,x2,y2,K_p);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% MAIN LOOP
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
simdata = zeros(Ns+1,16);                % table of simulation data



for i=1:Ns+1
     t = (i-1) * h;  
    %Heading maneuver 
    if (x2-eta(1))^2 + (y2-eta(2))^2 < R^2
       x2 = WP(1, counter);
       y2 = WP(2, counter);
       psi_ref = LOS(eta(1),eta(2),x1,y1,x2,y2,K_p);
       x1 = x2; 
       y1 = y2; 
       counter = counter + 1; 
    end
                       % time (s)
    R = Rzyx(0,0,eta(3));
    
    % current (should be added here)
    nu_r = nu;
    u_c = Vc*cos(betaVc);
    v_c = Vc*sin(betaVc);
    
    Bc = atan(nu(1)/nu(2)); %Crab angle 
    U = sqrt(nu_r(1)^2+nu_r(2)^2);
    Beta = asin(nu_r(1)/U); %Sideslip
    
    %Task 1A 
    nu_r(1) = nu(1)-u_c;
    nu_r(2) = nu(2)-v_c;
    
    
    % wind (should be added here)
    if t > 200
        gamma = nu_r(3)-betaVw-pi;
        Ywind = cy*sin(gamma); % expression for wind moment in sway should be added.
        Nwind = cn*sin(2*gamma); % expression for wind moment in yaw should be added.
    else
        Ywind = 0;
        Nwind = 0;
    end
    tau_env = 0.5*pa*Vw^2*[0 Ywind*A_Lw Nwind*A_Fw]';
    
    % state-dependent time-varying matrices
    CRB = m * nu(3) * [ 0 -1 -xg 
                        1  0  0 
                        xg 0  0  ];
                    
    % coriolis due to added mass
    CA = [  0   0   Yvdot * nu_r(2) + Yrdot * nu_r(3)
            0   0   -Xudot * nu_r(1) 
          -Yvdot * nu_r(2) - Yrdot * nu_r(3)    Xudot * nu_r(1)   0];
    N = CRB + CA + D;
    
    % nonlinear surge damping
    Rn = L/visc * abs(nu_r(1));
    Cf = 0.075 / ( (log(Rn) - 2)^2 + eps);
    Xns = -0.5 * rho * (B*L) * (1 + k) * Cf * abs(nu_r(1)) * nu_r(1);
    
    % cross-flow drag
    Ycf = 0;
    Ncf = 0;
    dx = L/10;
    Cd_2D = Hoerner(B,T);
    for xL = -L/2:dx:L/2
        vr = nu_r(2);
        r = nu_r(3);
        Ucf = abs(vr + xL * r) * (vr + xL * r);
        Ycf = Ycf - 0.5 * rho * T * Cd_2D * Ucf * dx;
        Ncf = Ncf - 0.5 * rho * T * Cd_2D * xL * Ucf * dx;
    end
    d = -[Xns Ycf Ncf]';
    
    % reference models
    u_d = U_d; % Cruise speed
    
    xd_dot = Ad*xd + Bd*psi_ref;
    psi_d = xd(1); 
    r_d = xd(2); 
    
    % thrust  
    T_d = U_d*Xu/(t_thr-1);
    n_d = sqrt(T_d/(rho * Dia^4 * KT));
    thr = rho * Dia^4 * KT * abs(n_d) * n_d;    % thrust command (N)
    
    Q_d = rho*Dia^5*KQ*abs(n)*n;
    Q_f = 0;
    Y = Q_d/Km;
    Q_m = Y*(Km/Tm)*exp(-t/Tm);
    
    % control law
    %delta_c = 0.1;              % rudder angle command (rad)
    e_psi = ssa(eta(3)-psi_d);
    e_psi_diff = ssa(nu(3)-r_d);
    delta_c = -(Kp*e_psi + Ki*e_psi_integral + Kd*e_psi_diff);
    
    
    % ship dynamics
    nu_vector = [nu_r(3)*v_c; -nu_r(3)*u_c; 0];
    
    u = [ thr delta ]';
    tau = Bu(nu_r(1),delta) * u;
    nu_dot = nu_vector + Minv * (tau_env + tau - N * nu_r - d); 
    eta_dot = R * nu;
    
    
    % Rudder saturation and dynamics (Sections 9.5.2)
    if abs(delta_c) >= delta_max
        delta_c = sign(delta_c)*delta_max;
    end
    
    delta_dot = delta_c - delta;
    if abs(delta_dot) >= Ddelta_max
        delta_dot = sign(delta_dot)*Ddelta_max;
    end    
    
    % propeller dynamics
    Im = 100000; Tm = 10; Km = 0.6;         % propulsion parameters
    n_c = 10;                               % propeller speed (rps)
    %n_dot = (1/10) * (n_c - n);             % should be changed in Part 3
    n_dot = (Q_m-Q_d-Q_f)/Im;

    % store simulation data in a table (for testing)
    simdata(i,:) = [t n_c delta_c n delta eta' nu' u_d psi_d r_d Bc Beta];       
     
    % Euler integration
    eta = euler2(eta_dot,eta,h);
    nu  = euler2(nu_dot,nu,h);
    delta = euler2(delta_dot,delta,h);   
    n  = euler2(n_dot,n,h);
    xd = euler2(xd_dot,xd,h);
    e_psi_integral = euler2(e_psi,e_psi_integral,h);
    
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% PLOTS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
t       = simdata(:,1);                 % s
n_c     = 60 * simdata(:,2);            % rpm
delta_c = (180/pi) * simdata(:,3);      % deg
n       = 60 * simdata(:,4);            % rpm
delta   = (180/pi) * simdata(:,5);      % deg
x       = simdata(:,6);                 % m
y       = simdata(:,7);                 % m
psi     = (180/pi) * simdata(:,8);      % deg
u       = simdata(:,9);                 % m/s
v       = simdata(:,10);                % m/s
r       = (180/pi) * simdata(:,11);     % deg/s
u_d     = simdata(:,12);                % m/s
psi_d   = (180/pi) * simdata(:,13);     % deg
r_d     = (180/pi) * simdata(:,14);     % deg/s
Bc     = (180/pi) * simdata(:,15);     % deg




figure(1)
figure(gcf)
subplot(311)
plot(y,x,'linewidth',2); axis('equal')
title('North-East positions (m)'); xlabel('time (s)'); 
subplot(312)
plot(t,psi,t,psi_d,'linewidth',2);
title('Actual and desired yaw angles (deg)'); xlabel('time (s)');
subplot(313)
plot(t,r,t,r_d,'linewidth',2);
title('Actual and desired yaw rates (deg/s)'); xlabel('time (s)');

figure(2)
figure(gcf)
subplot(311)
plot(t,u,t,u_d,'linewidth',2);
title('Actual and desired surge velocities (m/s)'); xlabel('time (s)');
subplot(312)
plot(t,n,t,n_c,'linewidth',2);
title('Actual and commanded propeller speed (rpm)'); xlabel('time (s)');
subplot(313)
plot(t,delta,t,delta_c,'linewidth',2);
title('Actual and commanded rudder angles (deg)'); xlabel('time (s)');

figure(3) 
figure(gcf)
subplot(211)
plot(t,u,'linewidth',2);
title('Actual surge velocity (m/s)'); xlabel('time (s)');
subplot(212)
plot(t,v,'linewidth',2);
title('Actual sway velocity (m/s)'); xlabel('time (s)');

%figure(4) 
%figure(gcf)
%subplot(211)
%plot(t,Bc,'linewidth',2);
%title('Crab Angle'); xlabel('time (s)');
%subplot(212)
%plot(t,Beta,'linewidth',2);
%title('Sideslip'); xlabel('time (s)');



