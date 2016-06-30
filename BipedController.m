classdef BipedController < matlab.System & matlab.system.mixin.Propagates
    
    properties (Nontunable)
        Ts = 1e-3
        env = struct();
    end

    properties
        phase_rate = 1.6;
        target_dx = 0;
    end
    
    
    properties (Access = private)
        phase
        footstep_target_right
        footstep_target_right_last
        footstep_target_left
        footstep_target_left_last
        angle_target_right_last
        angle_target_left_last
        length_trajectory
        angle_trajectory
        body_angle_trajectory
    end
    
    
    methods (Access = protected)
        function setupImpl(obj)
            obj.phase = struct('right', 0, 'left', 0);
            obj.length_trajectory = struct(...
                'phase',  {0.0, 0.35, 0.45, 0.5,  0.55, 0.65, 1.0}, ...
                'torque', {6.0, 6.0,  0.0,  0.0,  0.0,  6.0,  6.0}, ...
                'target', {0.8, 0.8,  0.76, 0.73, 0.76, 0.8,  0.8}, ...
                'kp',     {3e2, 3e2,  1e2,  1e2,  1e2,  3e2,  3e2}, ...
                'kd',     {3e0, 3e0,  1e0,  1e0,  1e0,  3e0,  3e0});
            obj.angle_trajectory = struct(...
                'phase',  {0.0, 0.3, 0.7, 1.0}, ...
                'torque', {1.0, 0.0, 0.0, 1.0}, ...
                'target', {0.0, 0.0, 1.0, 1.0}, ...
                'kp',     {0.0, 4e1, 1e2, 0.0}, ...
                'kd',     {0.0, 1e0, 4e0, 0.0});
            obj.body_angle_trajectory = struct(...
                'phase',  { 0.0,  0.2,  0.3,  0.7,  0.8,  1.0}, ...
                'torque', { 0.0,  0.0,  0.0,  0.0,  0.0,  0.0}, ...
                'target', { 0.0,  0.0,  0.0,  0.0,  0.0,  0.0}, ...
                'kp',     {-4e1, -4e1,  0.0,  0.0, -4e1, -4e1}, ...
                'kd',     {-4e0, -4e0,  0.0,  0.0, -4e0, -4e0});
        end
        
        
        function [u, dbg] = stepImpl(obj, t, X)
            
            % Increase leg phases with time
            obj.phase.right = obj.phase.right + obj.Ts * obj.phase_rate;
            obj.phase.left  = obj.phase.left  + obj.Ts * obj.phase_rate;
            
            % Update leg targets
            foot_extension = (0.5 * X.body.dx - 0.15 * (obj.target_dx - X.body.dx)) / obj.phase_rate;
            if obj.phase.right >= 1
                obj.footstep_target_right_last = obj.footstep_target_right;
                obj.footstep_target_left = X.body.x + foot_extension;
                obj.footstep_target_right = X.body.x + 2 * foot_extension;
            end
            if obj.phase.left >= 1
                obj.footstep_target_left_last = obj.footstep_target_left;
                obj.footstep_target_right = X.body.x + foot_extension;
                obj.footstep_target_left = X.body.x + 2 * foot_extension;
            end
            
            % Limit phases to [0, 1)
            obj.phase.right = obj.phase.right - floor(obj.phase.right);
            obj.phase.left  = obj.phase.left  - floor(obj.phase.left);
            
            % Initialize torque struct
            u.right.l_eq = 0;
            u.right.theta_eq = 0;
            u.left.l_eq = 0;
            u.left.theta_eq = 0;
            
            % Phase determines leg length control directly
            u.right.l_eq = eval_trajectory(interp_trajectory(obj.length_trajectory, obj.phase.right), ...
                X.right.l_eq, X.right.dl_eq);
            u.left.l_eq = eval_trajectory(interp_trajectory(obj.length_trajectory, obj.phase.left), ...
                X.left.l_eq, X.left.dl_eq);
            
            % Angle targets are modulated by footstep target location
            horizontal_push = 0;
            
            tvals_right = interp_trajectory(obj.angle_trajectory, obj.phase.right);
            tvals_right.torque = tvals_right.torque * horizontal_push;
            tvals_right.dtorque = tvals_right.dtorque * horizontal_push;
            x_target_right = obj.footstep_target_right_last + ...
                tvals_right.target * (obj.footstep_target_right - obj.footstep_target_right_last);
            tvals_right.target = real(asin(complex((x_target_right - X.body.x) / X.right.l))) - X.body.theta;
            tvals_right.dtarget = (tvals_right.target - obj.angle_target_right_last) / obj.Ts;
            obj.angle_target_right_last = tvals_right.target;
            u.right.theta_eq = eval_trajectory(tvals_right, X.right.theta_eq, X.right.dtheta_eq);
            
            tvals_left = interp_trajectory(obj.angle_trajectory, obj.phase.left);
            tvals_left.torque = tvals_left.torque * horizontal_push;
            tvals_left.dtorque = tvals_left.dtorque * horizontal_push;
            x_target_left = obj.footstep_target_left_last + ...
                tvals_left.target * (obj.footstep_target_left - obj.footstep_target_left_last);
            tvals_left.target = real(asin(complex((x_target_left - X.body.x) / X.left.l))) - X.body.theta;
            tvals_left.dtarget = (tvals_left.target - obj.angle_target_left_last) / obj.Ts;
            obj.angle_target_left_last = tvals_left.target;
            u.left.theta_eq = eval_trajectory(tvals_left, X.left.theta_eq, X.left.dtheta_eq);
            
            % Body target control is determined by phase and modulated by
            % leg force later
            u.right.theta_eq = u.right.theta_eq + ...
                eval_trajectory(interp_trajectory(obj.body_angle_trajectory, obj.phase.right), ...
                X.body.theta, X.body.dtheta);
            u.left.theta_eq = u.left.theta_eq + ...
                eval_trajectory(interp_trajectory(obj.body_angle_trajectory, obj.phase.left), ...
                X.body.theta, X.body.dtheta);
            
            
            % Modulate leg angle forces to limit foot slip
            
            dbg = [tvals_right.target, X.right.theta, obj.phase.right, obj.footstep_target_right, obj.footstep_target_right_last, x_target_right];
        end
        
        
        function resetImpl(obj)
            obj.phase.right = 0;
            obj.phase.left = 0.5;
            obj.footstep_target_right = 0;
            obj.footstep_target_right_last = 0;
            obj.footstep_target_left = 0;
            obj.footstep_target_left_last = 0;
            obj.angle_target_right_last = 0;
            obj.angle_target_left_last = 0;
        end
        
        
        function [sz1, sz2] = getOutputSizeImpl(~)
            sz1 = [1 1];
            sz2 = [1 6];
            
        end
        
        function [dt1, dt2] = getOutputDataTypeImpl(~)
            dt1 = 'control_bus';
            dt2 = 'double';
        end
        
        function [cm1, cm2] = isOutputComplexImpl(~)
            cm1 = false;
            cm2 = false;
        end
        
        function [fs1, fs2] = isOutputFixedSizeImpl(~)
            fs1 = true;
            fs2 = true;
        end
    end
    
    
    methods (Access = private)
        
    end
end



function tvals = interp_trajectory(tpoints, phase)

i = 2;
while tpoints(i).phase < phase
    i = i + 1;
end

phase_diff = tpoints(i).phase - tpoints(i - 1).phase;
p = (phase - tpoints(i - 1).phase) / phase_diff;

tvals.phase = phase;
tvals.torque = tpoints(i - 1).torque + p * (tpoints(i).torque - tpoints(i - 1).torque);
tvals.dtorque = (tpoints(i).torque - tpoints(i - 1).torque) / phase_diff;
tvals.target = tpoints(i - 1).target + p * (tpoints(i).target - tpoints(i - 1).target);
tvals.dtarget = (tpoints(i).target - tpoints(i - 1).target) / phase_diff;
tvals.kp = tpoints(i - 1).kp + p * (tpoints(i).kp - tpoints(i - 1).kp);
tvals.kd = tpoints(i - 1).kd + p * (tpoints(i).kd - tpoints(i - 1).kd);
end


function torque = eval_trajectory(tvals, x, dx)
torque = tvals.torque + ...
    (tvals.kp * (tvals.target - x)) + ...
    (tvals.kd * (tvals.dtarget - dx));
end
        
