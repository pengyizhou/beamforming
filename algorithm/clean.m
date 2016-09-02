clear all
c = 340;
fs = 44.1e3;
f = 2.7e3;
maxIterations = 100;
% Load array
load data/arrays/Nor848A-4.mat
%w = ones(1, numel(xPos))/numel(xPos);
w = hiResWeights;
nSensors = numel(xPos);

%Scanning points
distanceToScanningPlane = 1.75; %[m]
numberOfScanningPointsX = 40;
numberOfScanningPointsY = 30;

coveringAngleX = 48.5;
coveringAngleY = 35;
maxScanningPlaneExtentX = tan(coveringAngleX*pi/180)*distanceToScanningPlane;
maxScanningPlaneExtentY = tan(coveringAngleY*pi/180)*distanceToScanningPlane;

scanningAxisX = -maxScanningPlaneExtentX:2*maxScanningPlaneExtentX/(numberOfScanningPointsX-1):maxScanningPlaneExtentX;
scanningAxisY = -maxScanningPlaneExtentY:2*maxScanningPlaneExtentY/(numberOfScanningPointsY-1):maxScanningPlaneExtentY;

[scanningPointsX, scanningPointsY] = meshgrid(scanningAxisX, scanningAxisY);
[thetaScanningAngles, phiScanningAngles] = convertCartesianToPolar(scanningPointsX, scanningPointsY, distanceToScanningPlane);


% Set parameters of incoming narrowband signal(s)
xPosSource = [0.4 -0.8 -0.2 0.8 0];
yPosSource = [0 -0.3 0.4 0.6 -0.4];
zPosSource = distanceToScanningPlane;
amplitudes = [2 3.5 1.5 2 0];
[thetaArrivalAngles, phiArrivalAngles] = convertCartesianToPolar(xPosSource, yPosSource, zPosSource);




%Create input signal
inputSignal = createSignal(xPos, yPos, f, c, fs, thetaArrivalAngles, phiArrivalAngles, amplitudes);


%Create steering vector/matrix
e = steeringVector(xPos, yPos, f, c, thetaScanningAngles, phiScanningAngles);


% CLEAN method

%Safety factor 0 < loopGain < 1
loopGain = 0.9;

%Initialise cross spectral matrix (CSM)
D = inputSignal*inputSignal';
D(logical(eye(nSensors))) = 0;

%Initialise final clean image
Q = zeros(numberOfScanningPointsY, numberOfScanningPointsX);

%Initialise break criterion
sumOfCSM = sum(sum(abs(D)));
sumOfDegradedCSM = sumOfCSM;

% --- iteration start ---
    
for it = 1:maxIterations
    

    % -------------------------------------------------------
    % 1. Calculate dirty map
    P = zeros(numberOfScanningPointsY, numberOfScanningPointsX);
    for scanningPointY = 1:numberOfScanningPointsY
        for scanningPointX = 1:numberOfScanningPointsX
            ee = reshape(e(scanningPointY, scanningPointX, :), nSensors, 1);
            P(scanningPointY, scanningPointX) = (w.*ee')*D*(ee.*w');
        end
    end
    
    % Plot original delay-and-sum source distribution (dirty map)
    if it==1
        plotSteeredResponseXY(P, scanningPointsX, scanningPointsY, 1)
        hold on
        plot3(xPosSource, yPosSource, ones(1, numel(xPosSource))*60, 'k+')
    end
    
    
    % -------------------------------------------------------
    % 2. Find peak value and its position in dirty map
    [maxPeakValue, maxPeakIndx] = max(P(:));
    [maxPeakValueYIndx, maxPeakValueXIndx] = ind2sub(size(P), maxPeakIndx);
    
    %maxPeakValueXLocation = scanningPointsX(maxPeakValueXIndx);
    %maxPeakValueYLocation = scanningPointsY(maxPeakValueYIndx);
    
    
    
    % -------------------------------------------------------
    % 3. Calculate the CSM induced by the peak source
    
    % Steering vector to location of peak source
    g = reshape(e(maxPeakValueYIndx, maxPeakValueXIndx, :), nSensors, 1);
    
    % Cross spectral matrix induced by peak source in that direction (eq. 11)
    G = g*g';
    G(logical(eye(nSensors))) = 0;
    
    
%     %PSF from location of peak source
%     Pmax = zeros(numberOfScanningPointsY,numberOfScanningPointsX);
%     for scanningPointY = 1:numberOfScanningPointsY
%         for scanningPointX = 1:numberOfScanningPointsX
%             ee = reshape(e(scanningPointY, scanningPointX, :), nSensors, 1);
%             Pmax(scanningPointY, scanningPointX) = (w.*ee')*G*(ee.*w');
% 
%         end
%     end
%     
%     %Subtract PSF from peak source from dirty map
%     P = P - maxPeakValue*Pmax;
%     
%     if it==1
%         plotSteeredResponseXY(P, scanningPointsX, scanningPointsY, 3)
%         hold on
%         plot3(xPosSource, yPosSource, ones(1, numel(xPosSource))*60, 'k+')
%     end
    
    
    % -------------------------------------------------------
    % 4. New updated map with clean beam from peak source location (eq. 13)
    % Clean beam with specified width and max value of 1
    PmaxCleanBeam = zeros(numberOfScanningPointsY, numberOfScanningPointsX);
    PmaxCleanBeam(maxPeakValueYIndx, maxPeakValueXIndx) = 1;
    
    % Calculate the source strength distribution
    Q = Q + loopGain*maxPeakValue*PmaxCleanBeam;
    
    
    % -------------------------------------------------------
    % 5. Calculate degraded cross spectral matrix (eq. 14)
    % Basically removing the PSF from that location of the plot
    D = D - loopGain*maxPeakValue*G;
    D(logical(eye(nSensors))) = 0;
    
    
    % Stop the iteration if the degraded CSM contains more information than
    % in the previous iteration
    sumOfCSM = sum(sum(abs(D)));
    if sumOfCSM > sumOfDegradedCSM
        disp(['Converged after ' num2str(it) ' iterations'])
        break;
    end
    sumOfDegradedCSM = sumOfCSM;
    
    % --- iteration end ---
    
end

% 6. Source plot is written as summation of clean beams and remaining dirty map
Q = Q + P;



plotSteeredResponseXY(Q, scanningPointsX, scanningPointsY, 2)
hold on
plot3(xPosSource, yPosSource, ones(1, numel(xPosSource))*60, 'k+')





