function [segments,score,Hist,HistDiff,area,Edge,DTex,meanCC,meanLGTex,meanSaliency,adj,Rnum]=FinalMerging_v5(segments,score,Hist,HistDiff,area,Edge,DTex,LabIm,meanCC,textureImg,meanLGTex,SaliencyMap,meanSaliency,adj,LongContourMap25,LongContourMap80,edge_map,Rnum,Nseg)

    if  Rnum>=15
        SVTh=0.42; 
    elseif Rnum>11 && Rnum<15
        SVTh=0.5;
    else % Rnum<=11
        SVTh=0.6; 
    end
    W=1200;
    
    CC1=LabIm(:,:,1); CC2=LabIm(:,:,2); CC3=LabIm(:,:,3);
    [Val,Loc]=sort(score(:)); % in ascending order
    Loc=Loc(~isinf(Val));
    L_border = get_L_Border( segments );
    for order=1:length(Loc)  
        [L1,L2] = ind2sub(size(score),Loc(order));
        adjBorder= get_Adj_Border( L_border, L1, L2);   
        BndInd=find(adjBorder);
        L1_border_length=length(find(L_border==L1));
        L2_border_length=length(find(L_border==L2));
        contact_rate=length(BndInd)*0.5/min( L1_border_length, L2_border_length);
        minArea=min(area(L1),area(L2));
        if minArea<=300
            SVTh=1;
        elseif minArea<=650
            SVTh=SVTh+0.1;
        end
        dSV=abs(meanSaliency(L1)-meanSaliency(L2));
        if  contact_rate>=0.05 && dSV<=SVTh
            idxL2= (segments==L2); len2=sum(idxL2(:));
            idxL1= (segments==L1); len1=sum(idxL1(:));
            segments(idxL2)=L1; % merge segment L2 into L1
            Rnum=Rnum-1;
            if Rnum>Nseg   
                % update info.
                score(:,L2)=inf; score(L2,:)=inf;
                HistDiff(:,L2)=inf; HistDiff(L2,:)=inf;
                Hist{L1}=Hist{L1}+Hist{L2}; Hist{L2}=[];
                    
                for i=1:length(textureImg)
                   meanLGTex(i,L1)=sum(textureImg{i}(idxL2 | idxL1))/(len2+len1);
                end
                meanLGTex(:,L2)=NaN;
                meanCC(1,L1)=sum(CC1(idxL2 | idxL1))/(len2+len1);  meanCC(1,L2)=NaN;
                meanCC(2,L1)=sum(CC2(idxL2 | idxL1))/(len2+len1);  meanCC(2,L2)=NaN;
                meanCC(3,L1)=sum(CC3(idxL2 | idxL1))/(len2+len1);  meanCC(3,L2)=NaN;
                meanSaliency(L1)=sum(SaliencyMap(idxL2 | idxL1))/(len2+len1); meanSaliency(L2)=NaN;
                clear len1 len2 idxL1 idxL2
                
                % The area of L1 is now that of L1 and L2
                area(L1) = area(L1)+area(L2);
                area(L2) = NaN;                              
                % L1 inherits the adjacancy matrix entries of L2
                adj(L1,:) = adj(L1,:) | adj(L2,:);
                adj(:,L1) = adj(:,L1) | adj(:,L2);        
                adj(L1,L1) = 0;  % Ensure L1 is not connected to itself
                % Disconnect L2 from the adjacency matrix
                adj(L2,:) = 0;
                adj(:,L2) = 0;
                
                L_border = get_L_Border( segments );
                neighbor=find(adj(L1,:));
                SizeNeighbor=length(neighbor);
                Labstd=[meanCC(1,L1),meanCC(2,L1),meanCC(3,L1)];
                H1=sqrt(Hist{L1}/area(L1));
                for k=1:SizeNeighbor
                    Labsample=[meanCC(1,neighbor(k)),meanCC(2,neighbor(k)),meanCC(3,neighbor(k))];
                    de00=deltaE2000(Labstd, Labsample,[20,1,1]);
                    %HistDiff(L1,neighbor(k))=getHistDiff(2,'LAB',L1, neighbor(k),segments,LabIm); 
                    H2=sqrt(Hist{neighbor(k)}/area(neighbor(k)));            
                    HistDiff(L1,neighbor(k))=-(H1*H2'+0.000001);
                    HistDiff(neighbor(k),L1)=HistDiff(L1,neighbor(k)); 

                    adjBorder= get_Adj_Border( L_border, L1, neighbor(k));   
                    BndInd=find(adjBorder);
                    Edge(L1,neighbor(k)).Rate25=sum(LongContourMap25(BndInd))/length(BndInd);
                    Edge(neighbor(k),L1).Rate25=Edge(L1,neighbor(k)).Rate25;
                    Edge(L1,neighbor(k)).Rate80=sum(LongContourMap80(BndInd))/length(BndInd);
                    Edge(neighbor(k),L1).Rate80=Edge(L1,neighbor(k)).Rate80;
                    Edge(L1,neighbor(k)).Strength=sum(edge_map(BndInd))/length(BndInd);
                    Edge(neighbor(k),L1).Strength=Edge(L1,neighbor(k)).Strength;
                    
                    vecT1=meanLGTex(:,L1); vecT2=meanLGTex(:,neighbor(k));
                    DTex(L1,neighbor(k))=sqrt(sum(abs(vecT1-vecT2).^2));
                    DTex(neighbor(k),L1)=DTex(L1,neighbor(k));
                    
                    minArea=min(area(L1),area(neighbor(k)));                                             
                    score(L1,neighbor(k))= Edge(neighbor(k),L1).Rate80*(1+HistDiff(L1,neighbor(k)))*DTex(L1,neighbor(k))+Edge(L1,neighbor(k)).Strength*de00...
                                   -W/minArea+2*DTex(L1,neighbor(k))+HistDiff(L1,neighbor(k))+ Edge(neighbor(k),L1).Rate25;
                                     
                    score(neighbor(k),L1) = score(L1,neighbor(k)); 
                end
            end
            break
        end
    end
end