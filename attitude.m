% M-script for numerical integration of the attitude dynamics of a rigid 
% body represented by unit quaternions. The MSS m-files must be on your
% Matlab path in order to run the script.
%
% System:                      .
%                              q = T(q)w
%                              .
%                            I w - S(Iw)w = tau
% Control law:
%                            tau = constant
% 
% Definitions:             
%                            I = inertia matrix (3x3)
%                            S(w) = skew-symmetric matrix (3x3)
%                            T(q) = transformation matrix (4x3)
%                            tau = control input (3x1)
%                            w = angular velocity vector (3x1)
%                            q = unit quaternion vector (4x1)
%
% Author:                   2018-08-15 Thor I. Fossen and H�kon H. Helgesen

%% USER INPUTS
h = 0.1;                     % sample time (s)
N  = 400;                    % number of samples. Should be adjusted

% model parameters
m = 180;
r = 2;
I = m*r^2*eye(3);            % inertia matrix
I_inv = inv(I);

% constants
deg2rad = pi/180;   
rad2deg = 180/pi;

phi = -5*deg2rad;            % initial Euler angles
theta = 10*deg2rad;
psi = -20*deg2rad;

q = euler2q(phi,theta,psi);   % transform initial Euler angles to q

w = [0 0 0]';                 % initial angular rates

table = zeros(N+1,17);        % memory allocation

%% FOR-END LOOP
for i = 1:N+1,
   t = (i-1)*h;                  % time
   
   % Desired Angles
   phi_d = 0;
   theta_d = 15*cos(0.1*t);
   psi_d = 10*sin(0.05*t);
   bigT_d = [phi_d,theta_d,psi_d];
   
   % Desired angular velocities
   phi_d_dot = 0;
   theta_d_dot = -1.5*sin(0.1*t);
   psi_d_dot = 0.5*cos(0.05*t);
   bigT_d_dot = [phi_d_dot, theta_d_dot, psi_d_dot];
   
   
   % Delta Epsilon
   q_d = euler2q(phi_d, theta_d, psi_d); % Convert euler angles to quarterion
   q_d(2:4) = -1.*q_d(2:4); % Conjugate the quaternion
   q_tudd = quatprod(q_d,q); % Quaternion product
   eps_tudd = q_tudd(2:4);

   % Omega 
   
   T = Tzyx(phi_d,theta_d);
   
   w_d = inv(T)*bigT_d_dot';
   w_tudd = w - w_d;
   
   tau = -400*eye(3)*w_tudd-20*eps_tudd;

   [phi,theta,psi] = q2euler(q); % transform q to Euler angles

   [J,J1,J2] = quatern(q);       % kinematic transformation matrices
   
   q_dot = J2*w;                        % quaternion kinematics
   w_dot = I_inv*(Smtrx(I*w)*w + tau);  % rigid-body kinetics
   
   table(i,:) = [t q' phi theta psi w' tau' phi_d theta_d psi_d];  % store data in table
   
   q = q + h*q_dot;	             % Euler integration
   w = w + h*w_dot;
   
   q  = q/norm(q);               % unit quaternion normalization
end 

%% PLOT FIGURES
t       = table(:,1);  
q       = table(:,2:5); 
phi     = rad2deg*table(:,6);
theta   = rad2deg*table(:,7);
psi     = rad2deg*table(:,8);
w       = rad2deg*table(:,9:11);  
tau     = table(:,12:14);
phi_d   = table(:,15);
theta_d = table(:,16);
psi_d   = table(:, 17);

figure (1); clf;
hold on;
plot(t, phi, 'b');
plot(t, theta, 'r');
plot(t, psi, 'g');
plot(t, phi_d, '--b');
plot(t, theta_d, '--r');
plot(t, psi_d, '--g');
hold off;
grid on;
legend('\phi', '\theta', '\psi', '\phi_d', '\theta_d', '\psi_d');
title('Euler angles vs desired angles');
xlabel('time [s]'); 
ylabel('angle [deg]');

figure (2); clf;
hold on;
plot(t, w(:,1), 'b');
plot(t, w(:,2), 'r');
plot(t, w(:,3), 'g');
hold off;
grid on;
legend('x', 'y', 'z');
title('Angular velocities');
xlabel('time [s]'); 
ylabel('angular rate [deg/s]');

figure (3); clf;
hold on;
plot(t, tau(:,1), 'b');
plot(t, tau(:,2), 'r');
plot(t, tau(:,3), 'g');
hold off;
grid on;
legend('x', 'y', 'z');
title('Control input');
xlabel('time [s]'); 
ylabel('input [Nm]');
