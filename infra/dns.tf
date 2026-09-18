# Nom de domaine interne du site : routardo.azean.com.
#
# Choix : pas de zone hébergée dédiée. La zone "azean.com" existe déjà dans ce
# compte (Z0076746426XHFSVXWRW) et sert déjà api.azean.com et
# splunkbeautify.azean.com sur le même modèle (alias A vers CloudFront +
# CNAME de validation ACM). Déléguer une zone enfant coûterait 0,50 $/mois,
# imposerait d'y maintenir des NS, et n'apporterait rien tant que tout vit
# dans le même compte AWS.
#
# La zone parente est partagée avec d'autres projets : on la référence par son
# identifiant, on ne la gère pas ici. Aucune ressource de ce fichier ne touche
# aux enregistrements existants.

# --- Certificat (CloudFront exige us-east-1) ---

resource "aws_acm_certificate" "site" {
  provider = aws.us-east-1

  domain_name       = var.site_domain
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  # La policy du rôle de déploiement doit porter acm:* avant cette création.
  depends_on = [aws_iam_role_policy.gha_dns]
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for d in aws_acm_certificate.site.domain_validation_options : d.domain_name => {
      name   = d.resource_record_name
      type   = d.resource_record_type
      record = d.resource_record_value
    }
  }

  zone_id         = var.parent_hosted_zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true

  depends_on = [aws_iam_role_policy.gha_dns]
}

resource "aws_acm_certificate_validation" "site" {
  provider = aws.us-east-1

  certificate_arn         = aws_acm_certificate.site.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# --- Enregistrement DNS du site ---

# Alias A plutôt que CNAME : requête Route 53 non facturée, résolution directe
# vers CloudFront, et l'alias reste valable si la distribution change d'IP.
resource "aws_route53_record" "site" {
  zone_id = var.parent_hosted_zone_id
  name    = var.site_domain
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

# Pas d'enregistrement AAAA : la distribution a is_ipv6_enabled = false.
# Pour servir en IPv6, basculer ce champ dans cloudfront.tf et ajouter ici un
# second aws_route53_record de type AAAA, identique à celui ci-dessus.

# --- En-têtes de réponse : projet interne, pas d'indexation ---

# robots.txt et les balises meta couvrent les robots qui lisent le HTML.
# X-Robots-Tag couvre aussi le CSS, les images et tout ce qui n'est pas du HTML,
# et s'applique même si robots.txt n'est pas récupéré.
resource "aws_cloudfront_response_headers_policy" "noindex" {
  name    = "elroutardo-noindex"
  comment = "Projet interne : interdit l'indexation, en-tetes de securite de base"

  custom_headers_config {
    items {
      header   = "X-Robots-Tag"
      value    = "noindex, nofollow, noarchive, nosnippet"
      override = true
    }
  }

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 31536000
      include_subdomains         = false
      preload                    = false
      override                   = true
    }
    content_type_options {
      override = true
    }
    frame_options {
      frame_option = "DENY"
      override     = true
    }
    referrer_policy {
      referrer_policy = "same-origin"
      override        = true
    }
  }

  depends_on = [aws_iam_role_policy.gha_dns]
}
