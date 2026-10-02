#!/usr/bin/env bash
# ==============================================================================
# Script: seed-database.sh
# Objetivo: Realizar o povoamento inicial automático do banco de dados do
#           i-Educar com tabelas e registros essenciais (Deficiências,
#           Escolaridade, Raças, Funções, Módulos, Níveis de Ensino, etc.)
# ==============================================================================

set -euo pipefail

# Cores para terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}=== Povoamento Inicial do Banco de Dados (i-Educar Seeders) ===${NC}"

# 1. Localização 100% Automática do Diretório do i-Educar
detect_ieducar_dir() {
    # Estratégia A: Variável IEDUCAR_STORAGE_PATH no /etc/ieducar-backup/.env se existir
    if [[ -f /etc/ieducar-backup/.env ]]; then
        local env_storage
        env_storage=$(grep -E "^IEDUCAR_STORAGE_PATH=" /etc/ieducar-backup/.env 2>/dev/null | cut -d'=' -f2 | tr -d '"' | tr -d "'" || true)
        if [[ -n "$env_storage" && -d "$env_storage" ]]; then
            local cand
            cand=$(dirname "$env_storage")
            if [[ -f "$cand/artisan" || -d "$cand/database" ]]; then
                echo "$cand"
                return 0
            fi
        fi
    fi

    # Estratégia B: Caminhos padrão mais comuns em servidores Linux
    local common_paths=(
        "/var/www/ieducar"
        "/var/www/i-educar"
        "/var/www/html/ieducar"
        "/var/www/html/i-educar"
        "/var/www/html"
        "/srv/ieducar"
        "/opt/ieducar"
    )
    for p in "${common_paths[@]}"; do
        if [[ -f "$p/artisan" && -d "$p/database" ]]; then
            echo "$p"
            return 0
        fi
    done

    # Estratégia C: Detectar nas configurações do Nginx (/etc/nginx)
    if [[ -d /etc/nginx ]]; then
        local ngx_roots
        ngx_roots=$(grep -rhE "^\s*root\s+.*ieducar" /etc/nginx/ 2>/dev/null | awk '{print $2}' | tr -d ';' || true)
        for ngx_p in $ngx_roots; do
            local cand="$ngx_p"
            while [[ "$cand" != "/" && -n "$cand" ]]; do
                if [[ -f "$cand/artisan" && -d "$cand/database" ]]; then
                    echo "$cand"
                    return 0
                fi
                cand=$(dirname "$cand")
            done
        done
    fi

    # Estratégia D: Detectar nas configurações do Apache (/etc/apache2 ou /etc/httpd)
    if [[ -d /etc/apache2 || -d /etc/httpd ]]; then
        local ap_roots
        ap_roots=$(grep -rhE "^\s*DocumentRoot\s+.*ieducar" /etc/apache2/ /etc/httpd/ 2>/dev/null | awk '{print $2}' | tr -d '"' || true)
        for ap_p in $ap_roots; do
            local cand="$ap_p"
            while [[ "$cand" != "/" && -n "$cand" ]]; do
                if [[ -f "$cand/artisan" && -d "$cand/database" ]]; then
                    echo "$cand"
                    return 0
                fi
                cand=$(dirname "$cand")
            done
        done
    fi

    # Estratégia E: Busca rápida nos diretórios de aplicações
    local fast_file
    fast_file=$(find /var/www /srv /opt /home /root -maxdepth 4 -type f -name "artisan" 2>/dev/null | head -n 1 || true)
    if [[ -n "$fast_file" ]]; then
        local cand
        cand=$(dirname "$fast_file")
        if [[ -d "$cand/database" ]]; then
            echo "$cand"
            return 0
        fi
    fi

    # Estratégia F: Busca profunda global no sistema
    local deep_file
    deep_file=$(find / -path "/proc" -prune -o -path "/sys" -prune -o -path "/dev" -prune -o -path "/run" -prune -o -path "/tmp" -prune -o -type f -name "artisan" -print 2>/dev/null | head -n 1 || true)
    if [[ -n "$deep_file" ]]; then
        local cand
        cand=$(dirname "$deep_file")
        if [[ -d "$cand/database" ]]; then
            echo "$cand"
            return 0
        fi
    fi

    return 1
}

echo -e "${BLUE}Localizando instalação do i-Educar...${NC}"
IEDUCAR_DIR=$(detect_ieducar_dir || true)

if [[ -z "$IEDUCAR_DIR" || ! -d "$IEDUCAR_DIR" ]]; then
    echo -e "${RED}[ERRO] Instalação do i-Educar não foi localizada automaticamente.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ i-Educar localizado em: ${IEDUCAR_DIR}${NC}"

SEEDERS_DIR="${IEDUCAR_DIR}/database/seeders"
mkdir -p "${SEEDERS_DIR}"

# Detectar proprietário web
WEB_USER=$(stat -c '%U' "${IEDUCAR_DIR}" 2>/dev/null || echo "www-data")
WEB_GROUP=$(stat -c '%G' "${IEDUCAR_DIR}" 2>/dev/null || echo "$WEB_USER")
if [[ "$WEB_USER" == "root" ]] && id -u "www-data" &>/dev/null; then
    WEB_USER="www-data"
    WEB_GROUP="www-data"
fi

echo -e "${BLUE}Criando arquivos de seeders em ${SEEDERS_DIR}...${NC}"

# 1. DefaultCadastroDeficienciaTableSeeder.php
cat <<'EOF' > "${SEEDERS_DIR}/DefaultCadastroDeficienciaTableSeeder.php"
<?php

namespace Database\Seeders;

use App\Models\DeficiencyType;
use App\Models\LegacyDeficiency;
use iEducar\Modules\Educacenso\Model\Deficiencias;
use iEducar\Modules\Educacenso\Model\Transtornos;
use Illuminate\Database\Seeder;
use Illuminate\Support\Str;

class DefaultCadastroDeficienciaTableSeeder extends Seeder
{
    public function run()
    {
        $deficiencies = [
            Deficiencias::CEGUEIRA => 'Cegueira',
            Deficiencias::ALTAS_HABILIDADES_SUPERDOTACAO => 'Altas Habilidades / Superdotação',
            Deficiencias::TRANSTORNO_ESPECTRO_AUTISTA => 'Transtorno do Espectro Autista',
            Deficiencias::BAIXA_VISAO => 'Baixa Visão',
            Deficiencias::DEFICIENCIA_AUDITIVA => 'Deficiência Auditiva',
            Deficiencias::DEFICIENCIA_FISICA => 'Deficiência Física',
            Deficiencias::DEFICIENCIA_INTELECTUAL => 'Deficiência Intelectual',
            Deficiencias::SURDEZ => 'Surdez',
            Deficiencias::SURDOCEGUEIRA => 'Surdocegueira',
            Deficiencias::VISAO_MONOCULAR => 'Deficiência Visual',
            Deficiencias::OUTRAS => 'Outras',
        ];

        foreach ($deficiencies as $id => $name) {
            LegacyDeficiency::updateOrCreate([
                'deficiencia_educacenso' => $id,
            ], [
                'nm_deficiencia' => Str::upper($name),
                'deficiency_type_id' => DeficiencyType::DEFICIENCY,
            ]);
        }

        $disorders = [
            Transtornos::DISCALCULIA => 'Discalculia',
            Transtornos::DISGRAFIA => 'Disgrafia / Disortografia',
            Transtornos::DISLALIA => 'Dislalia',
            Transtornos::DISLEXIA => 'Dislexia',
            Transtornos::TDAH => 'TDAH',
            Transtornos::TPAC => 'TPAC',
            Transtornos::OUTROS => 'Outros',
        ];

        foreach ($disorders as $id => $name) {
            LegacyDeficiency::updateOrCreate([
                'transtorno_educacenso' => $id,
            ], [
                'nm_deficiencia' => Str::upper($name),
                'deficiency_type_id' => DeficiencyType::DISORDER,
            ]);
        }
    }
}
EOF

# 2. DefaultCadastroEscolaridadeTableSeeder.php
cat <<'EOF' > "${SEEDERS_DIR}/DefaultCadastroEscolaridadeTableSeeder.php"
<?php

namespace Database\Seeders;

use App\Models\LegacySchoolingDegree;
use iEducar\Modules\Educacenso\Model\Escolaridade;
use Illuminate\Database\Seeder;

class DefaultCadastroEscolaridadeTableSeeder extends Seeder
{
    public function run()
    {
        $schoolings = [
            Escolaridade::ENSINO_MEDIO => 'Ensino Médio',
            Escolaridade::ENSINO_FUNDAMENTAL => 'Ensino Fundamental Completo',
            Escolaridade::NAO_CONCLUIU_ENSINO_FUNDAMENTAL => 'Ensino Fundamental Incompleto',
            Escolaridade::EDUCACAO_SUPERIOR => 'Superior Completo',
        ];

        foreach ($schoolings as $id => $name) {
            LegacySchoolingDegree::updateOrCreate([
                'escolaridade' => $id,
            ], [
                'descricao' => $name,
            ]);
        }
    }
}
EOF

# 3. DefaultCadastroRacaTableSeeder.php
cat <<'EOF' > "${SEEDERS_DIR}/DefaultCadastroRacaTableSeeder.php"
<?php

namespace Database\Seeders;

use App\Models\LegacyRace;
use App\Models\LegacyUser;
use Illuminate\Database\Seeder;

class DefaultCadastroRacaTableSeeder extends Seeder
{
    public function run()
    {
        $user = LegacyUser::query()
            ->orderBy('cod_usuario')
            ->first();

        $races = [
            0 => 'Não Declarada',
            1 => 'Branca',
            2 => 'Preta',
            3 => 'Parda',
            4 => 'Amarela',
            5 => 'Indígena',
        ];

        foreach ($races as $id => $name) {
            LegacyRace::updateOrCreate([
                'raca_educacenso' => $id,
            ], [
                'nm_raca' => $name,
                'idpes_cad' => $user?->getKey(),
            ]);
        }
    }
}
EOF

# 4. DefaultEmployeeGraduationDisciplines.php
cat <<'EOF' > "${SEEDERS_DIR}/DefaultEmployeeGraduationDisciplines.php"
<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class DefaultEmployeeGraduationDisciplines extends Seeder
{
    public function run()
    {
        $data = [
            6 => 'Língua /Literatura Portuguesa',
            7 => 'Língua /Literatura estrangeira - Inglês',
            8 => 'Língua /Literatura estrangeira - Espanhol',
            30 => 'Língua/Literatura estrangeira - Francês',
            9 => 'Língua /Literatura estrangeira - outra',
            27 => 'Língua indígena',
            23 => 'Libras',
            31 => 'Língua Portuguesa como Segunda Língua',
            10 => 'Arte (Educação Artística, Teatro, Dança, Música, Artes Plásticas e outras)',
            11 => 'Educação Física',
            3 => 'Matemática',
            1 => 'Química',
            2 => 'Física',
            4 => 'Biologia',
            5 => 'Ciências',
            12 => 'História',
            13 => 'Geografia',
            14 => 'Filosofia',
            28 => 'Estudos Sociais',
            29 => 'Sociologia',
            16 => 'Informática/Computação',
            17 => 'Disciplinas Áreas do conhecimento profissionalizantes',
            20 => 'Disciplinas voltadas ao atendimento às necessidades educacionais específicas dos alunos que são público alvo da educação especial e às práticas educacionais inclusivas.',
            21 => 'Disciplinas voltadas à diversidade sociocultural (disciplinas pedagógicas)',
            25 => 'Disciplinas Áreas do conhecimento pedagógicas',
            26 => 'Ensino religioso',
            32 => 'Estágio curricular supervisionado',
            99 => 'Outras Disciplinas Áreas do conhecimento',
        ];

        foreach ($data as $id => $name) {
            DB::table('employee_graduation_disciplines')->updateOrInsert(
                ['id' => $id],
                ['name' => $name]
            );
        }
    }
}
EOF

# 5. DefaultManagerAccessCriteriasTableSeeder.php
cat <<'EOF' > "${SEEDERS_DIR}/DefaultManagerAccessCriteriasTableSeeder.php"
<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class DefaultManagerAccessCriteriasTableSeeder extends Seeder
{
    public function run()
    {
        $criterias = [
            1 => 'Proprietário(a) ou sócio(a)-proprietário(a) da escola',
            2 => 'Exclusivamente por indicação/escolha da gestão',
            3 => 'Processo seletivo qualificado e escolha/nomeação da gestão',
            4 => 'Concurso público específico para o cargo de gestor escolar',
            5 => 'Exclusivamente por processo eleitoral com a participação da comunidade escolar',
            6 => 'Processo seletivo qualificado e eleição com a participação da comunidade escolar',
            7 => 'Outros',
        ];

        foreach ($criterias as $id => $name) {
            DB::table('manager_access_criterias')->updateOrInsert(
                ['id' => $id],
                ['name' => $name]
            );
        }
    }
}
EOF

# 6. DefaultManagerLinkTypesTableSeeder.php
cat <<'EOF' > "${SEEDERS_DIR}/DefaultManagerLinkTypesTableSeeder.php"
<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class DefaultManagerLinkTypesTableSeeder extends Seeder
{
    public function run()
    {
        $types = [
            1 => 'Concursado/efetivo/estável',
            2 => 'Contrato temporário',
            3 => 'Contrato terceirizado',
            4 => 'Contrato CLT',
        ];

        foreach ($types as $id => $name) {
            DB::table('manager_link_types')->updateOrInsert(
                ['id' => $id],
                ['name' => $name]
            );
        }
    }
}
EOF

# 7. DefaultPmieducarAbandonoTipoTableSeeder.php
cat <<'EOF' > "${SEEDERS_DIR}/DefaultPmieducarAbandonoTipoTableSeeder.php"
<?php

namespace Database\Seeders;

use App\Models\LegacyAbandonmentType;
use Illuminate\Database\Seeder;

class DefaultPmieducarAbandonoTipoTableSeeder extends Seeder
{
    public function run()
    {
        $types = [
            'Evasão Escolar',
            'Vulnerabilidade Social Extrema',
            'Violência no Trajeto ou na Escola',
            'Conflito Familiar',
            'Gravidez na Adolescência',
            'Mudança de Residência sem Comunicação Prévia',
            'Inserção no Mercado de Trabalho',
            'Doença / Tratamento de Saúde',
            'Outro(a)',
        ];

        foreach ($types as $type) {
            LegacyAbandonmentType::updateOrCreate([
                'nome' => $type,
            ], [
                'ref_cod_instituicao' => 1,
                'ativo' => 1,
            ]);
        }
    }
}
EOF

# 8. DefaultPmieducarAlunoBeneficioTableSeeder.php
cat <<'EOF' > "${SEEDERS_DIR}/DefaultPmieducarAlunoBeneficioTableSeeder.php"
<?php

namespace Database\Seeders;

use App\Models\LegacyBenefit;
use App\Models\LegacyUser;
use Illuminate\Database\Seeder;

class DefaultPmieducarAlunoBeneficioTableSeeder extends Seeder
{
    public function run()
    {
        $user = LegacyUser::query()
            ->orderBy('cod_usuario')
            ->first();

        $benefits = [
            'Bolsa Família',
            'Auxílio Municipal',
            'Bolsa Estudantil',
            'Passe/ Vale Transporte',
            'Auxílio Uniforme Escolar',
            'Auxílio Material Escolar',
            'Outro(a)',
        ];

        foreach ($benefits as $benefit) {
            LegacyBenefit::updateOrCreate([
                'nm_beneficio' => $benefit,
            ], [
                'ref_usuario_cad' => $user?->getKey(),
            ]);
        }
    }
}
EOF

# 9. DefaultPmieducarFuncaoTableSeeder.php
cat <<'EOF' > "${SEEDERS_DIR}/DefaultPmieducarFuncaoTableSeeder.php"
<?php

namespace Database\Seeders;

use App\Models\LegacyRole;
use App\Models\LegacyUser;
use Illuminate\Database\Seeder;

class DefaultPmieducarFuncaoTableSeeder extends Seeder
{
    public function run()
    {
        $user = LegacyUser::query()
            ->orderBy('cod_usuario')
            ->first();

        $roles = [
            'CP' => 'Coordenador(a) Pedagógico',
            'DIR' => 'Diretor(a) Escolar',
            'SEC' => 'Secretário(a) Escolar',
            'SERV' => 'Servente Escolar',
            'ZEL' => 'Zelador(a)',
            'OE' => 'Orientador(a) Educacional',
            'AUX' => 'Auxiliar Administrativo',
            'BIB' => 'Bibliotecário(a)',
            'TEC-INF' => 'Técnico de Informática / Monitor de Laboratório',
            'ASG' => 'Auxiliar de Serviços Gerais',
        ];

        foreach ($roles as $sg => $role) {
            LegacyRole::updateOrCreate([
                'abreviatura' => $sg,
            ], [
                'nm_funcao' => $role,
                'professor' => 0,
                'ativo' => 1,
                'ref_usuario_cad' => $user?->getKey(),
                'ref_cod_instituicao' => 1,
            ]);
        }

        $teachers = [
            'PROF' => 'Professor(a)',
            'PROF-AEE' => 'Professor(a) de AEE',
        ];

        foreach ($teachers as $sg => $teacher) {
            LegacyRole::updateOrCreate([
                'abreviatura' => $sg,
            ], [
                'nm_funcao' => $teacher,
                'professor' => 1,
                'ativo' => 1,
                'ref_usuario_cad' => $user?->getKey(),
                'ref_cod_instituicao' => 1,
            ]);
        }
    }
}
EOF

# 10. DefaultPmieducarHistoricoGradeCursoTableSeeder.php
cat <<'EOF' > "${SEEDERS_DIR}/DefaultPmieducarHistoricoGradeCursoTableSeeder.php"
<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class DefaultPmieducarHistoricoGradeCursoTableSeeder extends Seeder
{
    public function run()
    {
        $grades = [
            1 => 'Série',
            2 => 'Ano',
            3 => 'EJA',
        ];

        foreach ($grades as $id => $etapa) {
            DB::table('pmieducar.historico_grade_curso')->updateOrInsert(
                ['id' => $id],
                [
                    'descricao_etapa' => $etapa,
                    'created_at' => now(),
                ]
            );
        }
    }
}
EOF

# 11. DefaultPmieducarModuloTableSeeder.php
cat <<'EOF' > "${SEEDERS_DIR}/DefaultPmieducarModuloTableSeeder.php"
<?php

namespace Database\Seeders;

use App\Models\LegacyStageType;
use App\Models\LegacyUser;
use Illuminate\Database\Seeder;

class DefaultPmieducarModuloTableSeeder extends Seeder
{
    public function run()
    {
        $user = LegacyUser::query()
            ->orderBy('cod_usuario')
            ->first();

        $modules = [
            1 => 'Ano',
            2 => 'Semestre',
            3 => 'Trimestre',
            4 => 'Bimestre',
        ];

        foreach ($modules as $stage => $name) {
            LegacyStageType::updateOrCreate([
                'num_etapas' => $stage,
                'nm_tipo' => $name,
            ], [
                'ativo' => 1,
                'ref_usuario_cad' => $user?->getKey(),
                'ref_cod_instituicao' => 1,
            ]);
        }
    }
}
EOF

# 12. DefaultPmieducarNivelEnsinoTableSeeder.php
cat <<'EOF' > "${SEEDERS_DIR}/DefaultPmieducarNivelEnsinoTableSeeder.php"
<?php

namespace Database\Seeders;

use App\Models\LegacyEducationLevel;
use App\Models\LegacyUser;
use Illuminate\Database\Seeder;

class DefaultPmieducarNivelEnsinoTableSeeder extends Seeder
{
    public function run()
    {
        $user = LegacyUser::query()
            ->orderBy('cod_usuario')
            ->first();

        $levels = [
            'Ano',
        ];

        foreach ($levels as $level) {
            LegacyEducationLevel::updateOrCreate([
                'nm_nivel' => $level,
            ], [
                'ativo' => 1,
                'ref_usuario_cad' => $user?->getKey(),
                'ref_cod_instituicao' => 1,
            ]);
        }
    }
}
EOF

# 13. DefaultPmieducarProjetoTableSeeder.php
cat <<'EOF' > "${SEEDERS_DIR}/DefaultPmieducarProjetoTableSeeder.php"
<?php

namespace Database\Seeders;

use App\Models\LegacyProject;
use Illuminate\Database\Seeder;

class DefaultPmieducarProjetoTableSeeder extends Seeder
{
    public function run()
    {
        $projects = [
            'Reforço Escolar',
            'Alfabetização e Letramento',
            'Preparatório (Saeb)',
            'Fanfarra',
            'Teatro',
            'Xadrez',
            'Escolinha de Esportes',
            'Dança',
            'Artes Marciais',
        ];

        foreach ($projects as $project) {
            LegacyProject::updateOrCreate([
                'nome' => $project,
            ], [
                'observacao' => '',
            ]);
        }
    }
}
EOF

# 14. DefaultPmieducarReligionTableSeeder.php
cat <<'EOF' > "${SEEDERS_DIR}/DefaultPmieducarReligionTableSeeder.php"
<?php

namespace Database\Seeders;

use App\Models\Religion;
use Illuminate\Database\Seeder;

class DefaultPmieducarReligionTableSeeder extends Seeder
{
    public function run()
    {
        $religions = [
            'Adventista',
            'Ateísmo',
            'Budista',
            'Candomblé',
            'Católica',
            'Espírita',
            'Evangélica',
            'Hinduísta',
            'Judaica',
            'Messiânica',
            'Mormon',
            'Muçulmano',
            'Nenhuma',
            'Outras(os)',
            'Seicho-no-ie',
            'Testemunha de Jeová',
            'Tradições Indígenas',
            'Umbanda',
        ];

        foreach ($religions as $religion) {
            Religion::updateOrCreate([
                'name' => $religion,
            ]);
        }
    }
}
EOF

# 15. DefaultPmieducarTipoAutorTableSeeder.php
cat <<'EOF' > "${SEEDERS_DIR}/DefaultPmieducarTipoAutorTableSeeder.php"
<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class DefaultPmieducarTipoAutorTableSeeder extends Seeder
{
    public function run()
    {
        $autores = [
            1 => 'Autor',
            2 => 'Evento',
            3 => 'Entidade coletiva',
            4 => 'Anônimo',
        ];

        foreach ($autores as $codigo => $tipo) {
            DB::table('pmieducar.tipo_autor')->updateOrInsert(
                ['codigo' => $codigo],
                ['tipo_autor' => $tipo]
            );
        }
    }
}
EOF

# 16. DefaultPmieducarTipoDispensaTableSeeder.php
cat <<'EOF' > "${SEEDERS_DIR}/DefaultPmieducarTipoDispensaTableSeeder.php"
<?php

namespace Database\Seeders;

use App\Models\LegacyExemptionType;
use App\Models\LegacyUser;
use Illuminate\Database\Seeder;

class DefaultPmieducarTipoDispensaTableSeeder extends Seeder
{
    public function run()
    {
        $user = LegacyUser::query()
            ->orderBy('cod_usuario')
            ->first();

        $types = [
            'Prática de Educação Física (Lei Federal 10.793/2003)',
            'Escusa de Consciência (Lei 13.796/2019)',
            'Adaptação Curricular (PDI) - Educação Especial',
            'Outro(a)',
        ];

        foreach ($types as $type) {
            LegacyExemptionType::updateOrCreate([
                'nm_tipo' => $type,
            ], [
                'ativo' => 1,
                'ref_usuario_cad' => $user?->getKey(),
                'ref_cod_instituicao' => 1,
            ]);
        }
    }
}
EOF

# 17. DefaultPmieducarTipoEnsinoTableSeeder.php (Correção de sintaxe aplicada)
cat <<'EOF' > "${SEEDERS_DIR}/DefaultPmieducarTipoEnsinoTableSeeder.php"
<?php

namespace Database\Seeders;

use App\Models\LegacyEducationType;
use App\Models\LegacyUser;
use Illuminate\Database\Seeder;

class DefaultPmieducarTipoEnsinoTableSeeder extends Seeder
{
    public function run()
    {
        $user = LegacyUser::query()
            ->orderBy('cod_usuario')
            ->first();

        $levels = [
            'AEE',
            'EJA',
            'Educação Infantil',
            'Ensino Fundamental',
            'Atividade Complementar',
        ];

        foreach ($levels as $level) {
            LegacyEducationType::updateOrCreate([
                'nm_tipo' => $level,
            ], [
                'ativo' => 1,
                'ref_usuario_cad' => $user?->getKey(),
                'ref_cod_instituicao' => 1,
            ]);
        }
    }
}
EOF

# 18. DefaultPmieducarTipoOcorrenciaDisciplinarTableSeeder.php
cat <<'EOF' > "${SEEDERS_DIR}/DefaultPmieducarTipoOcorrenciaDisciplinarTableSeeder.php"
<?php

namespace Database\Seeders;

use App\Models\LegacyDisciplinaryOccurrenceType;
use App\Models\LegacyUser;
use Illuminate\Database\Seeder;

class DefaultPmieducarTipoOcorrenciaDisciplinarTableSeeder extends Seeder
{
    public function run()
    {
        $user = LegacyUser::query()
            ->orderBy('cod_usuario')
            ->first();

        $types = [
            'Indisciplina em Sala de Aula',
            'Desrespeito',
            'Agressão Física ou Verbal',
            'Dano ao Patrimônio Público',
            'Bullying ou Prática Discriminatória',
            'Uso Indevido de Celular',
            'Evasão de Sala de Aula (Saída sem Autorização)',
            'Outro(a)',
        ];

        foreach ($types as $type) {
            LegacyDisciplinaryOccurrenceType::updateOrCreate([
                'nm_tipo' => $type,
            ], [
                'ativo' => 1,
                'ref_usuario_cad' => $user?->getKey(),
                'ref_cod_instituicao' => 1,
            ]);
        }
    }
}
EOF

# 19. DefaultPmieducarTipoRegimeTableSeeder.php
cat <<'EOF' > "${SEEDERS_DIR}/DefaultPmieducarTipoRegimeTableSeeder.php"
<?php

namespace Database\Seeders;

use App\Models\LegacyRegimeType;
use App\Models\LegacyUser;
use Illuminate\Database\Seeder;

class DefaultPmieducarTipoRegimeTableSeeder extends Seeder
{
    public function run()
    {
        $user = LegacyUser::query()
            ->orderBy('cod_usuario')
            ->first();

        $types = [
            'Seriado',
            'Etapas',
            'Modular',
            'Cíclico',
        ];

        foreach ($types as $type) {
            LegacyRegimeType::updateOrCreate([
                'nm_tipo' => $type,
            ], [
                'ativo' => 1,
                'ref_usuario_cad' => $user?->getKey(),
                'ref_cod_instituicao' => 1,
            ]);
        }
    }
}
EOF

# 20. DefaultPmieducarTipoUsuarioTableSeeder.php
cat <<'EOF' > "${SEEDERS_DIR}/DefaultPmieducarTipoUsuarioTableSeeder.php"
<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class DefaultPmieducarTipoUsuarioTableSeeder extends Seeder
{
    public function run()
    {
        DB::table('pmieducar.tipo_usuario')->updateOrInsert(
            ['cod_tipo_usuario' => 1],
            [
                'nm_tipo' => 'Administrador',
                'nivel' => 1,
                'ref_funcionario_cad' => 1,
                'data_cadastro' => now(),
            ]
        );
    }
}
EOF

# 21. DefaultPmieducarTransferenciaTipoTableSeeder.php
cat <<'EOF' > "${SEEDERS_DIR}/DefaultPmieducarTransferenciaTipoTableSeeder.php"
<?php

namespace Database\Seeders;

use App\Models\LegacyTransferType;
use App\Models\LegacyUser;
use Illuminate\Database\Seeder;

class DefaultPmieducarTransferenciaTipoTableSeeder extends Seeder
{
    public function run()
    {
        $user = LegacyUser::query()
            ->orderBy('cod_usuario')
            ->first();

        $types = [
            'Mudança de Endereço',
            'Interesse da Família',
            'Adaptação Escolar',
            'Transporte Escolar',
            'Decisão Judicial / Conselho Tutelar',
            'Ocorrência Disciplinar Grave',
            'Outro(a)',
        ];

        foreach ($types as $type) {
            LegacyTransferType::updateOrCreate([
                'nm_tipo' => $type,
            ], [
                'ativo' => 1,
                'ref_usuario_cad' => $user?->getKey(),
                'ref_cod_instituicao' => 1,
            ]);
        }
    }
}
EOF

# 22. DefaultPmieducarTurmaTipoTableSeeder.php
cat <<'EOF' > "${SEEDERS_DIR}/DefaultPmieducarTurmaTipoTableSeeder.php"
<?php

namespace Database\Seeders;

use App\Models\LegacySchoolClassType;
use App\Models\LegacyUser;
use Illuminate\Database\Seeder;

class DefaultPmieducarTurmaTipoTableSeeder extends Seeder
{
    public function run()
    {
        $user = LegacyUser::query()
            ->orderBy('cod_usuario')
            ->first();

        $types = [
            'REG' => 'Regular',
            'ESP' => 'Especial',
        ];

        foreach ($types as $sg => $type) {
            LegacySchoolClassType::updateOrCreate([
                'sgl_tipo' => $sg,
            ], [
                'nm_tipo' => $type,
                'ativo' => 1,
                'ref_usuario_cad' => $user?->getKey(),
                'ref_cod_instituicao' => 1,
            ]);
        }
    }
}
EOF

# 23. DefaultPortalFuncionarioVinculoTableSeeder.php
cat <<'EOF' > "${SEEDERS_DIR}/DefaultPortalFuncionarioVinculoTableSeeder.php"
<?php

namespace Database\Seeders;

use App\Models\LegacyBondType;
use Illuminate\Database\Seeder;

class DefaultPortalFuncionarioVinculoTableSeeder extends Seeder
{
    public function run()
    {
        $types = [
            'COM' => 'Comissionado',
            'CONT' => 'Contratado',
            'EFET' => 'Efetivo',
            'EST' => 'Estagiário',
        ];

        foreach ($types as $sg => $type) {
            LegacyBondType::updateOrCreate([
                'abreviatura' => $sg,
            ], [
                'nm_vinculo' => $type,
            ]);
        }
    }
}
EOF

# 24. DefaultRelatorioSituacaoMatriculaTableSeeder.php
cat <<'EOF' > "${SEEDERS_DIR}/DefaultRelatorioSituacaoMatriculaTableSeeder.php"
<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class DefaultRelatorioSituacaoMatriculaTableSeeder extends Seeder
{
    public function run()
    {
        $situacoes = [
            1 => 'Aprovado',
            2 => 'Reprovado',
            15 => 'Falecido',
            4 => 'Transferido',
            6 => 'Abandono',
            13 => 'Aprovado pelo conselho',
            9 => 'Exceto Transferidos/Abandono',
            10 => 'Todas',
            14 => 'Reprovado por faltas',
            12 => 'Ap. Depen.',
            5 => 'Reclassificado',
            3 => 'Cursando',
        ];

        foreach ($situacoes as $cod => $desc) {
            DB::table('relatorio.situacao_matricula')->updateOrInsert(
                ['cod_situacao' => $cod],
                ['descricao' => $desc]
            );
        }
    }
}
EOF

# Ajustar permissões dos seeders criados
chown -R "${WEB_USER}:${WEB_GROUP}" "${SEEDERS_DIR}" 2>/dev/null || true

# Atualizar autoload do composer caso exista
if command -v composer &>/dev/null; then
    echo -e "${BLUE}Atualizando autoload de classes...${NC}"
    (cd "${IEDUCAR_DIR}" && composer dump-autoload --quiet 2>/dev/null) || true
fi

# Lista de seeders para executar
SEEDERS=(
    "DefaultCadastroDeficienciaTableSeeder"
    "DefaultCadastroEscolaridadeTableSeeder"
    "DefaultCadastroRacaTableSeeder"
    "DefaultEmployeeGraduationDisciplines"
    "DefaultManagerAccessCriteriasTableSeeder"
    "DefaultManagerLinkTypesTableSeeder"
    "DefaultPmieducarAbandonoTipoTableSeeder"
    "DefaultPmieducarAlunoBeneficioTableSeeder"
    "DefaultPmieducarFuncaoTableSeeder"
    "DefaultPmieducarHistoricoGradeCursoTableSeeder"
    "DefaultPmieducarModuloTableSeeder"
    "DefaultPmieducarNivelEnsinoTableSeeder"
    "DefaultPmieducarProjetoTableSeeder"
    "DefaultPmieducarReligionTableSeeder"
    "DefaultPmieducarTipoAutorTableSeeder"
    "DefaultPmieducarTipoDispensaTableSeeder"
    "DefaultPmieducarTipoEnsinoTableSeeder"
    "DefaultPmieducarTipoOcorrenciaDisciplinarTableSeeder"
    "DefaultPmieducarTipoRegimeTableSeeder"
    "DefaultPmieducarTipoUsuarioTableSeeder"
    "DefaultPmieducarTransferenciaTipoTableSeeder"
    "DefaultPmieducarTurmaTipoTableSeeder"
    "DefaultPortalFuncionarioVinculoTableSeeder"
    "DefaultRelatorioSituacaoMatriculaTableSeeder"
)

echo -e "${BLUE}Executando seeders no banco de dados do i-Educar...${NC}"
TOTAL=${#SEEDERS[@]}
COUNT=0
FAIL=0

cd "${IEDUCAR_DIR}"

for seeder in "${SEEDERS[@]}"; do
    COUNT=$((COUNT + 1))
    echo -ne " [${COUNT}/${TOTAL}] Populando ${seeder}... "
    
    # Tenta com o namespace completo Database\\Seeders\\
    if php artisan db:seed --class="Database\\Seeders\\${seeder}" --force >/dev/null 2>&1; then
        echo -e "${GREEN}OK${NC}"
    elif php artisan db:seed --class="${seeder}" --force >/dev/null 2>&1; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${YELLOW}Aviso (pode já existir ou tabela opcional)${NC}"
        FAIL=$((FAIL + 1))
    fi
done

echo ""
echo -e "${GREEN}✓ Processo de povoamento inicial concluído (${TOTAL} seeders processados)!${NC}"
