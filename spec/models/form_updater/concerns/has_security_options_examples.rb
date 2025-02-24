# Copyright (C) 2012-2023 Zammad Foundation, https://zammad-foundation.org/

RSpec.shared_examples 'HasSecurityOptions' do |type:|
  context 'with security options' do
    let(:base_data) do
      case type
      when 'create'
        {
          'articleSenderType' => 'email-out',
        }
      when 'edit'
        {
          'article' => {
            'articleType' => 'email',
          },
        }
      end
    end
    let(:data) { base_data }

    before do
      Setting.set('smime_integration', true)
      Setting.set('smime_config', smime_config) if defined?(smime_config)
    end

    shared_examples 'resolving security field' do |expected_result:|
      it 'resolves security field' do
        result = resolved_result.resolve

        expect(result['security']).to include(expected_result)
      end
    end

    shared_examples 'not resolving security field' do
      it 'does not resolve security field' do
        result = resolved_result.resolve

        expect(result['security']).to be_nil
      end
    end

    it_behaves_like 'resolving security field', expected_result: { allowed: [], value: [] }

    context 'when secure mailing is not configured' do
      before do
        Setting.set('smime_integration', false)
      end

      it_behaves_like 'not resolving security field'
    end

    context 'without article type present' do
      let(:data) do
        base_data.tap do |data|
          case type
          when 'create'
            data.delete('articleSenderType')
          when 'edit'
            data['article'].delete('articleType')
          end
        end
      end

      it_behaves_like 'not resolving security field'
    end

    context 'with phone article type present' do
      let(:data) do
        base_data.tap do |data|
          case type
          when 'create'
            data['articleSenderType'] = 'phone-out'
          when 'edit'
            data['article']['articleType'] = 'phone'
          end
        end
      end

      it_behaves_like 'not resolving security field'
    end

    context 'when user has no agent permission' do
      let(:user) { create(:customer, groups: [group]) }

      it_behaves_like 'not resolving security field'
    end

    context 'with recipient present' do
      let(:recipient_email_address) { 'smime2@example.com' }
      let(:customer)                { create(:customer, email: recipient_email_address) }
      let(:data)                    do
        base_data.tap do |data|
          case type
          when 'create'
            data['customer_id'] = customer.id.to_s
          when 'edit'
            data['article']['to'] = [customer.email]
          end
        end
      end

      it_behaves_like 'resolving security field', expected_result: { allowed: [], value: [] }

      context 'with recipient certificate present' do
        before do
          create(:smime_certificate, fixture: recipient_email_address)
        end

        it_behaves_like 'resolving security field', expected_result: { allowed: ['encryption'], value: ['encryption'] }
      end
    end

    context 'with additional recipient present' do
      let(:recipient_email_address) { 'smime3@example.com' }
      let(:data) do
        base_data.tap do |data|
          case type
          when 'create'
            data['cc'] = [recipient_email_address]
          when 'edit'
            data['article']['cc'] = [recipient_email_address]
          end
        end
      end

      it_behaves_like 'resolving security field', expected_result: { allowed: [], value: [] }

      context 'with recipient certificate present' do
        before do
          create(:smime_certificate, fixture: recipient_email_address)
        end

        it_behaves_like 'resolving security field', expected_result: { allowed: ['encryption'], value: ['encryption'] }
      end

      context 'when email address is invalid' do
        let(:recipient_email_address) { 'invalid-email-address' }

        it_behaves_like 'resolving security field', expected_result: { allowed: [], value: [] }
      end
    end

    context 'with both recipient and additional recipient present' do
      let(:recipient_email_address1) { 'smime2@example.com' }
      let(:recipient_email_address2) { 'smime3@example.com' }
      let(:customer)                 { create(:customer, email: recipient_email_address1) }
      let(:data) do
        base_data.tap do |data|
          case type
          when 'create'
            data['customer_id'] = customer.id.to_s
            data['cc'] = [recipient_email_address2]
          when 'edit'
            data['article']['to'] = [customer.email]
            data['article']['cc'] = [recipient_email_address2]
          end
        end
      end

      it_behaves_like 'resolving security field', expected_result: { allowed: [], value: [] }

      context 'with only one recipient certificate present' do
        before do
          create(:smime_certificate, fixture: recipient_email_address1)
        end

        it_behaves_like 'resolving security field', expected_result: { allowed: [], value: [] }
      end

      context 'with both recipient certificates present' do
        before do
          create(:smime_certificate, fixture: recipient_email_address1)
          create(:smime_certificate, fixture: recipient_email_address2)
        end

        it_behaves_like 'resolving security field', expected_result: { allowed: ['encryption'], value: ['encryption'] }
      end
    end

    context 'with group present' do
      let(:data) { base_data.tap { |data| data['group_id'] = group.id } }

      it_behaves_like 'resolving security field', expected_result: { allowed: [], value: [] }

      context 'when the group has a configured sender address' do
        let(:system_email_address) { 'smime1@example.com' }
        let(:email_address)        { create(:email_address, email: system_email_address) }
        let(:group)                { create(:group, email_address: email_address) }

        it_behaves_like 'resolving security field', expected_result: { allowed: [], value: [] }

        context 'with sender certificate present' do
          before do
            create(:smime_certificate, :with_private, fixture: system_email_address)
          end

          it_behaves_like 'resolving security field', expected_result: { allowed: ['sign'], value: ['sign'] }
        end
      end
    end

    context 'with recipient and group present' do
      let(:recipient_email_address) { 'smime2@example.com' }
      let(:system_email_address)    { 'smime1@example.com' }
      let(:customer)                { create(:customer, email: recipient_email_address) }
      let(:email_address)           { create(:email_address, email: system_email_address) }
      let(:group)                   { create(:group, email_address: email_address) }
      let(:data) do
        base_data.tap do |data|
          case type
          when 'create'
            data['customer_id'] = customer.id.to_s
            data['group_id'] = group.id
          when 'edit'
            data['article']['to'] = [customer.email]
            data['group_id'] = group.id
          end
        end
      end

      it_behaves_like 'resolving security field', expected_result: { allowed: [], value: [] }

      context 'with recipient and sender certificates present' do
        before do
          create(:smime_certificate, fixture: recipient_email_address)
          create(:smime_certificate, :with_private, fixture: system_email_address)
        end

        it_behaves_like 'resolving security field', expected_result: { allowed: %w[encryption sign], value: %w[encryption sign] }

        context 'with default group configuration' do
          let(:smime_config) do
            {
              'group_id' => group_defaults
            }
          end
          let(:group_defaults) do
            {
              'default_encryption' => {
                group.id.to_s => default_encryption,
              },
              'default_sign'       => {
                group.id.to_s => default_sign,
              }
            }
          end
          let(:default_encryption) { true }
          let(:default_sign)       { true }

          it_behaves_like 'resolving security field', expected_result: { value: %w[encryption sign] }

          context 'when it has no value' do
            let(:group_defaults) { {} }

            it_behaves_like 'resolving security field', expected_result: { value: %w[encryption sign] }
          end

          context 'when encryption is disabled' do
            let(:default_encryption) { false }

            it_behaves_like 'resolving security field', expected_result: { value: ['sign'] }
          end

          context 'when signing is disabled' do
            let(:default_sign) { false }

            it_behaves_like 'resolving security field', expected_result: { value: ['encryption'] }
          end

          context 'when both encryption and signing are disabled' do
            let(:default_encryption) { false }
            let(:default_sign)       { false }

            it_behaves_like 'resolving security field', expected_result: { value: [] }
          end
        end
      end
    end
  end
end
