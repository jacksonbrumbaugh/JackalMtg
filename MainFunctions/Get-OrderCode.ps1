function Get-OrderCode {
  ("A,C,D,E,F,G,H,J,K,M,N,P,Q,R,S,T,U,V,W,X,Y,Z,2,3,4,5,6,7,9".split(",") | Get-Random -Count 5) -join ""
}
