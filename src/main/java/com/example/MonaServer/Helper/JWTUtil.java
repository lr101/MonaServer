package com.example.MonaServer.Helper;
import com.auth0.jwt.JWT;
import com.auth0.jwt.JWTVerifier;
import com.auth0.jwt.algorithms.Algorithm;
import com.auth0.jwt.exceptions.JWTCreationException;
import com.auth0.jwt.exceptions.JWTVerificationException;
import com.auth0.jwt.interfaces.Claim;
import com.auth0.jwt.interfaces.DecodedJWT;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.util.Date;
import java.util.HashMap;
import java.util.Map;

@Component
public class JWTUtil {

    @Value("${SECRET}")
    private final String secret = "secret";

    public String generateToken(String username, String password) throws IllegalArgumentException, JWTCreationException {
        return JWT.create()
                .withSubject("User Details")
                .withClaim("username", username)
                .withClaim("password", password)
                .withIssuedAt(new Date())
                .withIssuer("MONA_SERVER/LUKAS_REIM")
                .sign(Algorithm.HMAC256(secret));
    }

    public Map<String,String> validateTokenAndRetrieveSubject(String token)throws JWTVerificationException {
        JWTVerifier verifier = JWT.require(Algorithm.HMAC256(secret))
                .withSubject("User Details")
                .withIssuer("MONA_SERVER/LUKAS_REIM")
                .build();
        DecodedJWT jwt = verifier.verify(token);
        Map<String,String> m = new HashMap<>();
        Claim pass = jwt.getClaim("password");
        m.put("username", jwt.getClaim("username").asString());
        m.put("password", pass != null ? pass.asString() : null);
        return m;
    }

}
